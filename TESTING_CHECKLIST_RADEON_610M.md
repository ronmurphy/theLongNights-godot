# Radeon 610M Performance Testing Checklist

**Date Created:** November 1, 2025  
**Purpose:** Validate seasonal system optimization on low-end laptop  
**Target Hardware:** Radeon 610M mobile GPU  
**Baseline FPS:** ~45 FPS on medium graphics settings

---

## Pre-Test Setup

### 1. Ensure PerformanceMonitor is Active
Check that `project/project.godot` has this in the `[autoload]` section:
```ini
PerformanceMonitor="*res://long_nights/PerformanceMonitor.gd"
```

### 2. Set Graphics to Medium
- Open game
- Press ESC → Graphics Settings
- Select "Medium" profile
- Verify FPS is around 45

---

## Test 1: Baseline Performance (No Season Change)

**Purpose:** Establish normal FPS range without any season changes

### Commands:
```bash
# Press ~ to open console
fps true
perfmon start

# Play normally for 10-15 seconds
# Walk around, look at terrain, move camera

perfmon stop
```

### Record:
- [ ] Baseline FPS: _______ fps
- [ ] Min FPS: _______ fps
- [ ] Max FPS: _______ fps
- [ ] Avg Frame Time: _______ ms
- [ ] Fan noise during test: Quiet / Audible / Loud

---

## Test 2: Season Change Performance

**Purpose:** Measure FPS impact when changing seasons

### Commands:
```bash
# Press ~ to open console
perfmon start

# Change to a different season (pick one you're not currently in)
season spring
# OR
season summer
# OR
season autumn
# OR
season winter

# Wait 5-10 seconds for chunks to stabilize
# Walk around a bit

perfmon stop
```

### Record:
- [ ] Season changed from: _______ to: _______
- [ ] Baseline FPS: _______ fps
- [ ] Average FPS: _______ fps (___% of baseline)
- [ ] Min FPS: _______ fps
- [ ] Max FPS: _______ fps
- [ ] Max Frame Time: _______ ms
- [ ] Performance Assessment: Excellent / Good / Moderate / Poor
- [ ] Fan behavior: Stayed quiet / Brief spin-up / Loud spin-up / Stayed loud
- [ ] Subjective stutter/freeze: None / Barely noticeable / Noticeable / Significant

---

## Test 3: Multiple Season Changes (Stress Test)

**Purpose:** See if multiple rapid season changes cause cumulative issues

### Commands:
```bash
perfmon start
season spring
# Wait 3 seconds
season summer
# Wait 3 seconds
season autumn
# Wait 3 seconds
season winter
# Wait 3 seconds
perfmon stop
```

### Record:
- [ ] Average FPS across all changes: _______ fps
- [ ] Min FPS during test: _______ fps
- [ ] Fan behavior: _______
- [ ] Any stuttering or freezing: _______

---

## Results Interpretation

### ✅ Excellent (<5% FPS drop)
**Expected:** 43-45 FPS maintained  
**Action:** Optimization successful! No further work needed.

### ✅ Good (<15% FPS drop)
**Expected:** 38-42 FPS during season change  
**Action:** Optimization successful! Optional: implement LOD for even smoother experience.

### ⚠️ Moderate (15-30% FPS drop)
**Expected:** 32-38 FPS during season change  
**Action:** Implement deferred chunk updates to spread work over multiple frames.

### ❌ Poor (>30% FPS drop)
**Expected:** <32 FPS during season change  
**Action:** Implement both LOD-based updates AND deferred updates for low-end hardware.

---

## Next Steps Based on Results

### If Excellent or Good:
✅ **No further optimization needed!**
- Document the results
- Consider this issue resolved
- Low-end laptop users can play comfortably

### If Moderate:
⚠️ **Implement Deferred Updates** (~15k tokens remaining budget)
- Spread chunk regeneration over 1-2 seconds
- Eliminates frame time spikes
- Maintains visual smoothness

### If Poor:
❌ **Implement Multiple Optimizations** (~30k tokens remaining budget)
1. LOD-Based Updates (only regenerate visible chunks)
2. Deferred Updates (spread work over time)
3. Optional: Auto-reduce quality during season transitions

---

## Additional Notes

### Factors That May Affect Results:
- Background processes on laptop
- Battery vs. plugged-in performance
- Thermal throttling if laptop is hot
- Number of terrain chunks currently loaded

### Best Testing Conditions:
- Laptop plugged into power
- No other applications running
- Laptop has been on for 5+ minutes (warmed up)
- Test in same location in-game for consistency

---

## Report Template for Warp

When reporting results, copy this format:

```
Radeon 610M Test Results:

Test 1 (Baseline):
- FPS: 45 fps (example)
- Fan: Quiet

Test 2 (Season Change):
- FPS: 42 fps (93% of baseline)
- Min FPS: 38 fps
- Fan: Brief spin-up, then quiet
- Stutter: Barely noticeable
- Assessment: ✅ Good

Test 3 (Multiple Changes):
- FPS: 40 fps average
- Min FPS: 35 fps
- Fan: Stayed audible
- Stutter: Noticeable during transitions

Overall: Need deferred updates / Optimization successful / etc.
```

---

## Testing Complete!

Once you have the results, report back and I'll:
1. Analyze the performance data
2. Determine if further optimization is needed
3. Implement advanced optimizations if necessary (LOD, deferred updates, or both)

**Tokens Available:** ~121,000 (plenty for any follow-up optimizations)
