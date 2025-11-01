extends Node
## PerformanceMonitor - Simple FPS and frame time tracking
## Autoload this to monitor performance impact of seasonal changes

var _fps_history: Array[float] = []
var _frame_times: Array[float] = []
const HISTORY_SIZE = 120  # 2 seconds at 60fps

var _monitoring_active: bool = false
var _baseline_fps: float = 0.0
var _season_change_time: float = 0.0

func _ready() -> void:
	set_process(false)  # Start disabled

func _process(delta: float) -> void:
	if not _monitoring_active:
		return
	
	# Track FPS and frame time
	var current_fps = Engine.get_frames_per_second()
	var frame_time = delta * 1000.0  # Convert to milliseconds
	
	_fps_history.append(current_fps)
	_frame_times.append(frame_time)
	
	# Keep history size limited
	if _fps_history.size() > HISTORY_SIZE:
		_fps_history.pop_front()
		_frame_times.pop_front()

func start_monitoring() -> void:
	"""Start monitoring performance before a season change"""
	_monitoring_active = true
	set_process(true)
	_fps_history.clear()
	_frame_times.clear()
	_baseline_fps = Engine.get_frames_per_second()
	_season_change_time = Time.get_ticks_msec()
	print("📊 Performance monitoring started (baseline FPS: %.1f)" % _baseline_fps)

func stop_monitoring() -> String:
	"""Stop monitoring and return performance report"""
	_monitoring_active = false
	set_process(false)
	
	if _fps_history.is_empty():
		return "No performance data collected"
	
	# Calculate statistics
	var avg_fps = _calculate_average(_fps_history)
	var min_fps = _fps_history.min()
	var max_fps = _fps_history.max()
	
	var avg_frame_time = _calculate_average(_frame_times)
	var max_frame_time = _frame_times.max()
	
	var duration_ms = Time.get_ticks_msec() - _season_change_time
	
	# Build report
	var report = "\n📊 PERFORMANCE REPORT\n"
	report += "==================\n"
	report += "Duration: %.2f seconds\n" % (duration_ms / 1000.0)
	report += "Baseline FPS: %.1f\n" % _baseline_fps
	report += "Average FPS: %.1f (%.1f%% of baseline)\n" % [avg_fps, (avg_fps / _baseline_fps) * 100.0]
	report += "Min FPS: %.1f\n" % min_fps
	report += "Max FPS: %.1f\n" % max_fps
	report += "Avg Frame Time: %.2f ms\n" % avg_frame_time
	report += "Max Frame Time: %.2f ms\n" % max_frame_time
	
	# Performance assessment
	if avg_fps >= _baseline_fps * 0.95:
		report += "✅ Excellent: <5% FPS impact\n"
	elif avg_fps >= _baseline_fps * 0.85:
		report += "✅ Good: <15% FPS impact\n"
	elif avg_fps >= _baseline_fps * 0.70:
		report += "⚠️ Moderate: <30% FPS impact\n"
	else:
		report += "❌ Poor: >30% FPS impact\n"
	
	return report

func _calculate_average(arr: Array[float]) -> float:
	if arr.is_empty():
		return 0.0
	var sum = 0.0
	for val in arr:
		sum += val
	return sum / arr.size()

## Console command: Start monitoring
func cmd_perfmon_start(_args: PackedStringArray) -> void:
	start_monitoring()

## Console command: Stop monitoring and show report
func cmd_perfmon_stop(_args: PackedStringArray) -> void:
	print(stop_monitoring())
