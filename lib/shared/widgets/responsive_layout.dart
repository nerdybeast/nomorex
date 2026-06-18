import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

/// Returns true if the current screen width is below the mobile breakpoint.
bool isMobile(BuildContext context) =>
    MediaQuery.sizeOf(context).width < AppConstants.kMobileBreakpoint;
