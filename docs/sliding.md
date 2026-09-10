# Sliding (Issue #40)

Shift (rebindable in control settings) while grounded and moving at least 5.5 m/s begins a slide. Current movement direction is preserved; looking and shooting remain available. Initial speed is current speed +5, bounded to 13–18 m/s. Duration up to .85s, drag 10 m/s². There is no cooldown after ending (Issue #57): once standing, grounded, and moving fast enough, another press can start a new slide. Holding the key does not repeatedly trigger it.

Capsule height changes 1.7 -> 1.0, offset -0.35 keeps feet at the same level. Camera lowers smoothly from .6 to -.12. Walls/low speed/leaving ground end the active slide. Standing capsule is checked against the world before restoration; blocked players retain a low stance and can move at 3 m/s until clear. Jump requires headroom and cancels slide; the enemy-pull grapple preserves player sliding. Stage entry resets stance.

Dedicated logic: gameplay/player_slide.gd. Integration: main movement loop; Shift is the default slide input. Control settings apply saved bindings.

Tests: player_slide_test (stationary and airborne rejection, movement, ceiling clearance, immediate restart after natural end/cancellation/ceiling clearance, wall stop, reset, uphill/downhill); weapon_runtime_test; run_result_flow_test. player_slide_capture renders actual standing/slide camera views. No full-body slide animation is added because gameplay uses a first-person camera.
