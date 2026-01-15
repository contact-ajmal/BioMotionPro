# BioMotionPro Test Data

This directory contains sample motion capture files for testing BioMotionPro features.

## Files

| File | Format | Description |
|------|--------|-------------|
| `sample_walking.trc` | TRC | Marker trajectory data (25 frames, 16 markers) |
| `sample_grf.mot` | MOT/STO | Ground reaction force data (50 samples) |
| `sample_walking.c3d` | C3D | Full motion capture file (generated via Python) |

## Marker Set

The sample data uses standard biomechanics markers compatible with Plug-in Gait:

- **Pelvis**: LASI, RASI, LPSI, RPSI
- **Knees**: LKNE, RKNE
- **Ankles**: LANK, RANK
- **Feet**: LTOE, RTOE, LHEE, RHEE
- **Upper Body**: LSHO, RSHO, LELB, RELB

## Generating C3D File

C3D is a binary format. To generate the sample C3D file:

```bash
# Install ezc3d (one-time)
pip install ezc3d

# Generate the file
cd TestData
python3 generate_sample_c3d.py
```

## Testing Features

| Feature | Test File(s) |
|---------|--------------|
| File Loading | All files |
| Marker Visualization | `sample_walking.trc` or `.c3d` |
| Skeleton Detection | TRC/C3D (uses marker names) |
| Inverse Kinematics | TRC/C3D (calculates knee/elbow angles) |
| Analog Data | `sample_grf.mot` (force channels) |
| Gait Event Detection | `sample_grf.mot` (needs vertical force) |
| Report Generation | Any loaded file |
| Python Scripting | TRC/C3D (exports markers to CSV) |

## Notes

- TRC and MOT files are plain text and can be edited manually
- C3D files require specialized tools (ezc3d, BTK, etc.) to create
- Marker positions are in millimeters (mm)
- Frame rate is 100 Hz for markers
- Force data sample rate is 100 Hz (typically would be 1000+ Hz in real data)
