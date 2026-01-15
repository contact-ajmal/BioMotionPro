#!/usr/bin/env python3
"""
Generate a sample C3D file for BioMotionPro testing.
Requires: pip install ezc3d

Usage:
    python3 generate_sample_c3d.py
"""

import numpy as np

try:
    import ezc3d
except ImportError:
    print("ezc3d not installed. Install with: pip install ezc3d")
    print("Alternatively, use the TRC file which is a text-based format.")
    exit(1)

# Parameters
n_frames = 100
frame_rate = 100.0

# Marker labels (standard biomechanics markers)
labels = [
    "LASI", "RASI", "LPSI", "RPSI",  # Pelvis
    "LKNE", "RKNE",                    # Knees
    "LANK", "RANK",                    # Ankles
    "LTOE", "RTOE",                    # Toes
    "LHEE", "RHEE",                    # Heels
    "LSHO", "RSHO",                    # Shoulders
    "LELB", "RELB",                    # Elbows
]

n_markers = len(labels)

# Generate walking motion data
# X: Forward direction (progression)
# Y: Lateral direction
# Z: Vertical direction

data = np.zeros((4, n_markers, n_frames))  # 4 = X, Y, Z, residual

for frame in range(n_frames):
    t = frame / frame_rate
    progression = t * 1000  # 1 m/s walking speed, converted to mm
    
    # Pelvis markers (oscillate slightly with gait)
    pelvis_sway = 30 * np.sin(2 * np.pi * 2 * t)  # 2 Hz oscillation
    pelvis_height = 950 + 20 * np.cos(2 * np.pi * 2 * t)
    
    # LASI
    data[0, 0, frame] = progression
    data[1, 0, frame] = -150 + pelvis_sway
    data[2, 0, frame] = pelvis_height
    
    # RASI
    data[0, 1, frame] = progression
    data[1, 1, frame] = 150 + pelvis_sway
    data[2, 1, frame] = pelvis_height
    
    # LPSI
    data[0, 2, frame] = progression - 150
    data[1, 2, frame] = -100 + pelvis_sway
    data[2, 2, frame] = pelvis_height
    
    # RPSI
    data[0, 3, frame] = progression - 150
    data[1, 3, frame] = 100 + pelvis_sway
    data[2, 3, frame] = pelvis_height
    
    # Knee markers (simulate leg swing)
    left_phase = 2 * np.pi * t
    right_phase = left_phase + np.pi
    
    knee_height = 500
    
    # LKNE
    data[0, 4, frame] = progression + 100 * np.sin(left_phase)
    data[1, 4, frame] = -150
    data[2, 4, frame] = knee_height + 50 * np.sin(left_phase)
    
    # RKNE
    data[0, 5, frame] = progression + 100 * np.sin(right_phase)
    data[1, 5, frame] = 150
    data[2, 5, frame] = knee_height + 50 * np.sin(right_phase)
    
    # Ankle markers
    ankle_height = 80
    
    # LANK
    data[0, 6, frame] = progression + 150 * np.sin(left_phase)
    data[1, 6, frame] = -150
    data[2, 6, frame] = ankle_height + 30 * max(0, np.sin(left_phase))
    
    # RANK
    data[0, 7, frame] = progression + 150 * np.sin(right_phase)
    data[1, 7, frame] = 150
    data[2, 7, frame] = ankle_height + 30 * max(0, np.sin(right_phase))
    
    # Toe markers
    # LTOE
    data[0, 8, frame] = progression + 200 * np.sin(left_phase)
    data[1, 8, frame] = -150
    data[2, 8, frame] = 20 + 50 * max(0, np.sin(left_phase))
    
    # RTOE
    data[0, 9, frame] = progression + 200 * np.sin(right_phase)
    data[1, 9, frame] = 150
    data[2, 9, frame] = 20 + 50 * max(0, np.sin(right_phase))
    
    # Heel markers
    # LHEE
    data[0, 10, frame] = progression - 50 + 100 * np.sin(left_phase)
    data[1, 10, frame] = -150
    data[2, 10, frame] = 20 + 20 * max(0, np.sin(left_phase + np.pi/4))
    
    # RHEE
    data[0, 11, frame] = progression - 50 + 100 * np.sin(right_phase)
    data[1, 11, frame] = 150
    data[2, 11, frame] = 20 + 20 * max(0, np.sin(right_phase + np.pi/4))
    
    # Shoulder markers (constant relative position to pelvis)
    # LSHO
    data[0, 12, frame] = progression
    data[1, 12, frame] = -200
    data[2, 12, frame] = 1400
    
    # RSHO
    data[0, 13, frame] = progression
    data[1, 13, frame] = 200
    data[2, 13, frame] = 1400
    
    # Elbow markers (arm swing)
    arm_swing = 50 * np.sin(left_phase + np.pi)  # Counter to leg
    
    # LELB
    data[0, 14, frame] = progression + arm_swing
    data[1, 14, frame] = -350
    data[2, 14, frame] = 1200
    
    # RELB
    data[0, 15, frame] = progression - arm_swing
    data[1, 15, frame] = 350
    data[2, 15, frame] = 1200
    
    # Set residual to 0 (good quality)
    data[3, :, frame] = 0

# Create C3D structure
c3d = ezc3d.c3d()

# Set parameters
c3d["parameters"]["POINT"]["RATE"]["value"] = [frame_rate]
c3d["parameters"]["POINT"]["LABELS"]["value"] = labels
c3d["parameters"]["POINT"]["UNITS"]["value"] = ["mm"]

# Set data
c3d["data"]["points"] = data

# Write file
output_path = "sample_walking.c3d"
c3d.write(output_path)
print(f"✅ Created {output_path} with {n_frames} frames and {n_markers} markers")
print(f"   Markers: {', '.join(labels)}")
