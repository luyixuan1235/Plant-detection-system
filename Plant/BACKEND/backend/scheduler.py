from __future__ import annotations


class FloorRefreshScheduler:
	"""No-op scheduler for the plant-monitoring flow.

	The old project used YOLO/OpenCV video refresh jobs for seat detection. The
	current app only needs login, plant reports, image upload, and CNN prediction,
	so startup must not require cv2 or apscheduler.
	"""

	def __init__(self, interval_seconds: int | None = None) -> None:
		self.interval_seconds = interval_seconds
		self.started = False

	def start(self) -> None:
		self.started = True

	def shutdown(self) -> None:
		self.started = False


