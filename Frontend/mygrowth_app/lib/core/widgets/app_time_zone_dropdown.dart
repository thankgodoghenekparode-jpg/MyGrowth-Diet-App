import 'package:flutter/material.dart';

import 'app_text_field.dart';

/// Common IANA time zones that members can select for their profile and
/// prayer availability.
const appTimeZones = <String>[
  'Africa/Abidjan',
  'Africa/Accra',
  'Africa/Cairo',
  'Africa/Johannesburg',
  'Africa/Lagos',
  'Africa/Nairobi',
  'America/Anchorage',
  'America/Argentina/Buenos_Aires',
  'America/Chicago',
  'America/Denver',
  'America/Los_Angeles',
  'America/Mexico_City',
  'America/New_York',
  'America/Phoenix',
  'America/Sao_Paulo',
  'America/Toronto',
  'America/Vancouver',
  'Asia/Baghdad',
  'Asia/Bangkok',
  'Asia/Dhaka',
  'Asia/Dubai',
  'Asia/Hong_Kong',
  'Asia/Jakarta',
  'Asia/Jerusalem',
  'Asia/Karachi',
  'Asia/Kathmandu',
  'Asia/Kolkata',
  'Asia/Manila',
  'Asia/Riyadh',
  'Asia/Seoul',
  'Asia/Shanghai',
  'Asia/Singapore',
  'Asia/Tokyo',
  'Australia/Adelaide',
  'Australia/Brisbane',
  'Australia/Melbourne',
  'Australia/Perth',
  'Australia/Sydney',
  'Europe/Amsterdam',
  'Europe/Athens',
  'Europe/Berlin',
  'Europe/Istanbul',
  'Europe/London',
  'Europe/Madrid',
  'Europe/Moscow',
  'Europe/Paris',
  'Pacific/Auckland',
  'Pacific/Honolulu',
  'UTC',
];

class AppTimeZoneDropdown extends StatelessWidget {
  const AppTimeZoneDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.required = false,
  });

  final String value;
  final ValueChanged<String?> onChanged;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final zones = appTimeZones.contains(value)
        ? appTimeZones
        : [value, ...appTimeZones];
    return AppDropdown<String>(
      label: 'Time zone',
      required: required,
      value: value,
      items: [
        for (final zone in zones)
          DropdownMenuItem(value: zone, child: Text(zone)),
      ],
      onChanged: onChanged,
    );
  }
}
