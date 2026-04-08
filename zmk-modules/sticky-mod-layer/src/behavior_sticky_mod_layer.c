/*
 * Copyright (c) 2026
 *
 * SPDX-License-Identifier: MIT
 */

#define DT_DRV_COMPAT zmk_behavior_sticky_mod_layer

#include <zephyr/device.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

#include <drivers/behavior.h>

#include <zmk/behavior.h>
#include <zmk/endpoints.h>
#include <zmk/event_manager.h>
#include <zmk/events/keycode_state_changed.h>
#include <zmk/hid.h>
#include <zmk/keymap.h>

LOG_MODULE_DECLARE(zmk, CONFIG_ZMK_LOG_LEVEL);

#if DT_HAS_COMPAT_STATUS_OKAY(DT_DRV_COMPAT)

#define KEY_PRESS DEVICE_DT_NAME(DT_INST(0, zmk_behavior_key_press))
#define SML_POSITION_FREE UINT32_MAX
#define SML_MAX_HELD CONFIG_ZMK_BEHAVIOR_STICKY_MOD_LAYER_MAX_HELD

struct behavior_sticky_mod_layer_config {
    uint32_t release_after_ms;
    bool quick_release;
    bool ignore_modifiers;
    struct zmk_behavior_binding behavior;
};

struct active_sticky_mod_layer {
    uint32_t position;
#if IS_ENABLED(CONFIG_ZMK_SPLIT)
    uint8_t source;
#endif
    uint32_t param1;
    uint8_t continuation_layer;
    const struct behavior_sticky_mod_layer_config *config;
    bool timer_started;
    uint8_t modified_key_usage_page;
    uint32_t modified_key_keycode;
};

struct continuation_layer_state {
    bool active;
    bool timer_cancelled;
    int64_t release_at;
    struct k_work_delayable release_timer;
};

static struct active_sticky_mod_layer active_sticky_mod_layers[SML_MAX_HELD];
static struct continuation_layer_state continuation_layers[ZMK_KEYMAP_LAYERS_LEN];

static bool valid_layer(uint8_t layer) { return layer < ZMK_KEYMAP_LAYERS_LEN; }

static bool is_waiting_sticky(const struct active_sticky_mod_layer *sticky) {
    return sticky->position != SML_POSITION_FREE && sticky->timer_started &&
           sticky->modified_key_usage_page == 0 && sticky->modified_key_keycode == 0;
}

static struct active_sticky_mod_layer *
find_sticky_mod_layer(uint32_t position, struct zmk_behavior_binding behavior, uint32_t binding_param,
                      uint8_t continuation_layer) {
    for (int i = 0; i < SML_MAX_HELD; i++) {
        struct active_sticky_mod_layer *sticky = &active_sticky_mod_layers[i];
        if (sticky->position == position &&
            sticky->config->behavior.behavior_dev == behavior.behavior_dev &&
            sticky->param1 == binding_param && sticky->continuation_layer == continuation_layer) {
            return sticky;
        }
    }

    return NULL;
}

static struct active_sticky_mod_layer *
store_sticky_mod_layer(struct zmk_behavior_binding_event *event, uint32_t param1,
                       uint8_t continuation_layer,
                       const struct behavior_sticky_mod_layer_config *config) {
    for (int i = 0; i < SML_MAX_HELD; i++) {
        struct active_sticky_mod_layer *sticky = &active_sticky_mod_layers[i];
        if (sticky->position != SML_POSITION_FREE) {
            continue;
        }

        sticky->position = event->position;
#if IS_ENABLED(CONFIG_ZMK_SPLIT)
        sticky->source = event->source;
#endif
        sticky->param1 = param1;
        sticky->continuation_layer = continuation_layer;
        sticky->config = config;
        sticky->timer_started = false;
        sticky->modified_key_usage_page = 0;
        sticky->modified_key_keycode = 0;
        return sticky;
    }

    return NULL;
}

static void clear_sticky_mod_layer(struct active_sticky_mod_layer *sticky) {
    sticky->position = SML_POSITION_FREE;
}

static int press_sticky_behavior(struct active_sticky_mod_layer *sticky, int64_t timestamp) {
    struct zmk_behavior_binding binding = {
        .behavior_dev = sticky->config->behavior.behavior_dev,
        .param1 = sticky->param1,
    };
    struct zmk_behavior_binding_event event = {
        .position = sticky->position,
        .timestamp = timestamp,
#if IS_ENABLED(CONFIG_ZMK_SPLIT)
        .source = sticky->source,
#endif
    };

    return zmk_behavior_invoke_binding(&binding, event, true);
}

static int release_sticky_behavior(struct active_sticky_mod_layer *sticky, int64_t timestamp) {
    struct zmk_behavior_binding binding = {
        .behavior_dev = sticky->config->behavior.behavior_dev,
        .param1 = sticky->param1,
    };
    struct zmk_behavior_binding_event event = {
        .position = sticky->position,
        .timestamp = timestamp,
#if IS_ENABLED(CONFIG_ZMK_SPLIT)
        .source = sticky->source,
#endif
    };

    clear_sticky_mod_layer(sticky);
    return zmk_behavior_invoke_binding(&binding, event, false);
}

static int stop_continuation_layer_timer(uint8_t layer) {
    struct continuation_layer_state *state = &continuation_layers[layer];
    int timer_cancel_result = k_work_cancel_delayable(&state->release_timer);
    if (timer_cancel_result == -EINPROGRESS) {
        state->timer_cancelled = true;
    }

    return timer_cancel_result;
}

static int activate_continuation_layer(uint8_t layer) {
    struct continuation_layer_state *state = &continuation_layers[layer];
    if (state->active) {
        return 0;
    }

    state->active = true;
    return zmk_keymap_layer_activate(layer);
}

static int deactivate_continuation_layer(uint8_t layer) {
    struct continuation_layer_state *state = &continuation_layers[layer];
    stop_continuation_layer_timer(layer);
    if (!state->active) {
        state->timer_cancelled = false;
        return 0;
    }

    state->active = false;
    state->timer_cancelled = false;
    return zmk_keymap_layer_deactivate(layer);
}

static bool has_waiting_sticky_for_layer(uint8_t layer) {
    for (int i = 0; i < SML_MAX_HELD; i++) {
        if (active_sticky_mod_layers[i].continuation_layer == layer &&
            is_waiting_sticky(&active_sticky_mod_layers[i])) {
            return true;
        }
    }

    return false;
}

static void refresh_continuation_layer(uint8_t layer) {
    if (!valid_layer(layer)) {
        return;
    }

    if (!has_waiting_sticky_for_layer(layer)) {
        deactivate_continuation_layer(layer);
    }
}

static void schedule_continuation_layer_timeout(uint8_t layer, int64_t timestamp,
                                                uint32_t release_after_ms) {
    struct continuation_layer_state *state = &continuation_layers[layer];

    state->release_at = timestamp + release_after_ms;
    state->timer_cancelled = false;

    int32_t ms_left = state->release_at - k_uptime_get();
    if (ms_left > 0) {
        k_work_schedule(&state->release_timer, K_MSEC(ms_left));
    } else {
        k_work_schedule(&state->release_timer, K_NO_WAIT);
    }
}

static void release_waiting_stickies_for_layer(uint8_t layer, int64_t timestamp) {
    for (int i = 0; i < SML_MAX_HELD; i++) {
        struct active_sticky_mod_layer *sticky = &active_sticky_mod_layers[i];
        if (sticky->continuation_layer != layer || !is_waiting_sticky(sticky)) {
            continue;
        }

        release_sticky_behavior(sticky, timestamp);
    }
}

static int on_sticky_mod_layer_binding_pressed(struct zmk_behavior_binding *binding,
                                               struct zmk_behavior_binding_event event) {
    const struct device *dev = zmk_behavior_get_binding(binding->behavior_dev);
    const struct behavior_sticky_mod_layer_config *cfg = dev->config;
    uint8_t continuation_layer = binding->param2;

    if (!valid_layer(continuation_layer)) {
        LOG_ERR("Invalid continuation layer %d", continuation_layer);
        return ZMK_BEHAVIOR_OPAQUE;
    }

    struct active_sticky_mod_layer *sticky =
        find_sticky_mod_layer(event.position, cfg->behavior, binding->param1, continuation_layer);
    if (sticky != NULL) {
        release_sticky_behavior(sticky, event.timestamp);
        refresh_continuation_layer(continuation_layer);
    }

    stop_continuation_layer_timer(continuation_layer);

    sticky = store_sticky_mod_layer(&event, binding->param1, continuation_layer, cfg);
    if (sticky == NULL) {
        LOG_ERR("Unable to store sticky mod layer state, max held is %d", SML_MAX_HELD);
        return ZMK_BEHAVIOR_OPAQUE;
    }

    press_sticky_behavior(sticky, event.timestamp);
    return ZMK_BEHAVIOR_OPAQUE;
}

static int on_sticky_mod_layer_binding_released(struct zmk_behavior_binding *binding,
                                                struct zmk_behavior_binding_event event) {
    const struct device *dev = zmk_behavior_get_binding(binding->behavior_dev);
    const struct behavior_sticky_mod_layer_config *cfg = dev->config;
    uint8_t continuation_layer = binding->param2;
    struct active_sticky_mod_layer *sticky =
        find_sticky_mod_layer(event.position, cfg->behavior, binding->param1, continuation_layer);

    if (sticky == NULL) {
        LOG_ERR("Active sticky mod layer cleared too early");
        return ZMK_BEHAVIOR_OPAQUE;
    }

    if (sticky->modified_key_usage_page != 0 && sticky->modified_key_keycode != 0) {
        release_sticky_behavior(sticky, event.timestamp);
        refresh_continuation_layer(continuation_layer);
        return ZMK_BEHAVIOR_OPAQUE;
    }

    sticky->timer_started = true;
    activate_continuation_layer(continuation_layer);
    schedule_continuation_layer_timeout(continuation_layer, event.timestamp, cfg->release_after_ms);
    return ZMK_BEHAVIOR_OPAQUE;
}

static const struct behavior_driver_api behavior_sticky_mod_layer_driver_api = {
    .binding_pressed = on_sticky_mod_layer_binding_pressed,
    .binding_released = on_sticky_mod_layer_binding_released,
};

static int sticky_mod_layer_keycode_state_changed_listener(const zmk_event_t *eh);
static void continuation_layer_timer_handler(struct k_work *work);

ZMK_LISTENER(behavior_sticky_mod_layer, sticky_mod_layer_keycode_state_changed_listener);
ZMK_SUBSCRIPTION(behavior_sticky_mod_layer, zmk_keycode_state_changed);

static int sticky_mod_layer_keycode_state_changed_listener(const zmk_event_t *eh) {
    struct zmk_keycode_state_changed *ev = as_zmk_keycode_state_changed(eh);
    if (ev == NULL) {
        return ZMK_EV_EVENT_BUBBLE;
    }

    struct active_sticky_mod_layer *stickies_to_release[SML_MAX_HELD] = {0};
    bool layers_to_deactivate[ZMK_KEYMAP_LAYERS_LEN] = {0};
    const struct zmk_keycode_state_changed ev_copy = *ev;

    for (int i = 0; i < SML_MAX_HELD; i++) {
        struct active_sticky_mod_layer *sticky = &active_sticky_mod_layers[i];
        if (sticky->position == SML_POSITION_FREE) {
            continue;
        }

        if (strcmp(sticky->config->behavior.behavior_dev, KEY_PRESS) == 0 &&
            ZMK_HID_USAGE_ID(sticky->param1) == ev_copy.keycode &&
            ZMK_HID_USAGE_PAGE(sticky->param1) == ev_copy.usage_page &&
            SELECT_MODS(sticky->param1) == ev_copy.implicit_modifiers) {
            continue;
        }

        if (ev_copy.state) {
            if (sticky->config->ignore_modifiers && is_mod(ev_copy.usage_page, ev_copy.keycode)) {
                continue;
            }

            if (sticky->modified_key_usage_page != 0 || sticky->modified_key_keycode != 0) {
                continue;
            }

            stop_continuation_layer_timer(sticky->continuation_layer);

            if (continuation_layers[sticky->continuation_layer].release_at != 0 &&
                ev_copy.timestamp > continuation_layers[sticky->continuation_layer].release_at) {
                release_waiting_stickies_for_layer(
                    sticky->continuation_layer, continuation_layers[sticky->continuation_layer].release_at);
                deactivate_continuation_layer(sticky->continuation_layer);
                continue;
            }

            sticky->modified_key_usage_page = ev_copy.usage_page;
            sticky->modified_key_keycode = ev_copy.keycode;
            layers_to_deactivate[sticky->continuation_layer] = true;

            if (sticky->timer_started && sticky->config->quick_release) {
                stickies_to_release[i] = sticky;
            }
        } else if (sticky->timer_started &&
                   sticky->modified_key_usage_page == ev_copy.usage_page &&
                   sticky->modified_key_keycode == ev_copy.keycode) {
            stickies_to_release[i] = sticky;
        }
    }

    for (int layer = 0; layer < ZMK_KEYMAP_LAYERS_LEN; layer++) {
        if (layers_to_deactivate[layer]) {
            deactivate_continuation_layer(layer);
        }
    }

    bool event_reraised = false;
    for (int i = 0; i < SML_MAX_HELD; i++) {
        struct active_sticky_mod_layer *sticky = stickies_to_release[i];
        if (!sticky) {
            continue;
        }

        if (!event_reraised) {
            struct zmk_keycode_state_changed_event dupe_ev =
                copy_raised_zmk_keycode_state_changed(ev);
            ZMK_EVENT_RAISE_AFTER(dupe_ev, behavior_sticky_mod_layer);
            event_reraised = true;
        }

        uint8_t layer = sticky->continuation_layer;
        release_sticky_behavior(sticky, ev_copy.timestamp);
        refresh_continuation_layer(layer);
    }

    return event_reraised ? ZMK_EV_EVENT_CAPTURED : ZMK_EV_EVENT_BUBBLE;
}

static void continuation_layer_timer_handler(struct k_work *work) {
    struct k_work_delayable *d_work = k_work_delayable_from_work(work);
    struct continuation_layer_state *state =
        CONTAINER_OF(d_work, struct continuation_layer_state, release_timer);
    uint8_t layer = state - continuation_layers;

    if (state->timer_cancelled) {
        state->timer_cancelled = false;
        return;
    }

    release_waiting_stickies_for_layer(layer, state->release_at);
    deactivate_continuation_layer(layer);
}

static int behavior_sticky_mod_layer_init(const struct device *dev) {
    ARG_UNUSED(dev);

    static bool init_once = false;
    if (init_once) {
        return 0;
    }

    for (int i = 0; i < SML_MAX_HELD; i++) {
        active_sticky_mod_layers[i].position = SML_POSITION_FREE;
    }

    for (int i = 0; i < ZMK_KEYMAP_LAYERS_LEN; i++) {
        k_work_init_delayable(&continuation_layers[i].release_timer, continuation_layer_timer_handler);
        continuation_layers[i].active = false;
        continuation_layers[i].timer_cancelled = false;
        continuation_layers[i].release_at = 0;
    }

    init_once = true;
    return 0;
}

#define SML_INST(n)                                                                                \
    static const struct behavior_sticky_mod_layer_config behavior_sticky_mod_layer_config_##n = {  \
        .behavior = ZMK_KEYMAP_EXTRACT_BINDING(0, DT_DRV_INST(n)),                                 \
        .release_after_ms = DT_INST_PROP(n, release_after_ms),                                     \
        .quick_release = DT_INST_PROP(n, quick_release),                                           \
        .ignore_modifiers = DT_INST_PROP(n, ignore_modifiers),                                     \
    };                                                                                             \
    BEHAVIOR_DT_INST_DEFINE(n, behavior_sticky_mod_layer_init, NULL, NULL,                         \
                            &behavior_sticky_mod_layer_config_##n, POST_KERNEL,                    \
                            CONFIG_KERNEL_INIT_PRIORITY_DEFAULT,                                    \
                            &behavior_sticky_mod_layer_driver_api);

DT_INST_FOREACH_STATUS_OKAY(SML_INST)

#endif
