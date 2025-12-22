extends Node

# ============================================================
#  FILE: debug_utils.gd
#
#  ROLE: Global debug utility autoload
# ------------------------------------------------------------
#  Provides debug helper functions across the entire project.
#
#  SETUP:
#    1. Go to Project -> Project Settings -> Autoload
#    2. Add this script:
#       - Path: res://scripts/debug_utils.gd
#       - Name: DebugUtils
#       - Enable: ✓
#
#  USAGE:
#    DebugUtils.dprint("Your message here")
#    DebugUtils.dprint("Selected chunk: " + str(chunk))
# ============================================================


# Print with file path and line number
# Automatically extracts caller info from the call stack
static func dprint(message: String) -> void:
	var stack = get_stack()
	if stack.size() > 1:
		var caller = stack[1]  # Get caller info (index 0 is this function)
		var file_path = caller["source"]
		var file_name = file_path.get_file()  # Extract just filename
		var line = caller["line"]
		print("[%s:%d] %s" % [file_name, line, message])
	else:
		# Fallback if stack is unavailable
		print(message)


# Print warning with file path and line number
# Shows in yellow in the editor output
static func dwarn(message: String) -> void:
	var stack = get_stack()
	if stack.size() > 1:
		var caller = stack[1]
		var file_path = caller["source"]
		var file_name = file_path.get_file()
		var line = caller["line"]
		push_warning("[%s:%d] %s" % [file_name, line, message])
	else:
		push_warning(message)


# Print error with file path and line number
# Shows in red in the editor output
static func derror(message: String) -> void:
	var stack = get_stack()
	if stack.size() > 1:
		var caller = stack[1]
		var file_path = caller["source"]
		var file_name = file_path.get_file()
		var line = caller["line"]
		push_error("[%s:%d] %s" % [file_name, line, message])
	else:
		push_error(message)
