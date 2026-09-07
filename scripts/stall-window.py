#!/usr/bin/env python3
"""stall-window.py — during a host-frame stall, was the host ASKED? Count both sides.
  child side : my_dxmt_acquire_remote_layer (a new swapchain published to the host)
               macdrv_client_surface_present (the child drawing)
  host side  : update_remote_layer_frame_for (the host installing a frame)
               retire_superseded_layers      (the host processing a CREATE message)
A stall with child events but no host events is the host dropping them; the reverse is the child.

`sync_window_position` is the INTERNAL CONTROL and is why this settles anything: it runs on the
host at ~43/s and keeps doing so straight through the stall. So the trace is not blocked and the
host thread is not wedged -- which is what makes the absence of the child's events a measurement
rather than an artifact of the instrument.

Usage:  stall-window.py <run-dir> <t-start> <t-end>
        (get the window from host-frame-stalls.py, which prints the stall's start and duration)
(macgameport, 2026-09-06)"""
import re, sys, os
EV = {
 'acquire (child publishes)': re.compile(r'^(\d+\.\d+):\S+:trace:macdrv:my_dxmt_acquire_remote_layer'),
 'present (child draws)':     re.compile(r'^(\d+\.\d+):\S+:trace:macdrv:macdrv_client_surface_present'),
 'swapchain req (child asks)':re.compile(r'^(\d+\.\d+):\S+:trace:macdrv:macdrv_client_surface_acquire_metal_swapchain'),
 'install (host places)':     re.compile(r'^(\d+\.\d+):\S+:trace:macdrv:update_remote_layer_frame_for'),
 'retire (host got CREATE)':  re.compile(r'^(\d+\.\d+):\S+:trace:macdrv:retire_superseded_layers'),
 'sync_window_position':      re.compile(r'^(\d+\.\d+):\S+:trace:macdrv:sync_window_position'),
 'window_frame_changed':      re.compile(r'^(\d+\.\d+):\S+:trace:macdrv:macdrv_window_frame_changed'),
}
run, t0, t1 = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
counts = {k: 0 for k in EV}
before = {k: 0 for k in EV}
for line in open(os.path.join(run, 'stdout.txt'), errors='replace'):
    for k, rx in EV.items():
        m = rx.match(line)
        if m:
            t = float(m.group(1))
            if t0 <= t <= t1: counts[k] += 1
            elif t0 - 10 <= t < t0: before[k] += 1
            break
print('  %-28s %10s %10s' % ('event', 'in stall', 'prior 10s'))
for k in EV:
    print('  %-28s %10d %10d' % (k, counts[k], before[k]))
