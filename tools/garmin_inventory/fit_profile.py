"""Names for FIT message and field numbers.

Names come from the public FIT profile unless marked "community": those were
identified by the Gadgetbridge project and are not in Garmin's published
profile. A number missing here is reported as unknown, which is the point:
the inventory exists to surface what nobody has named yet.
"""

MESSAGES = {
    0: "file_id", 1: "capabilities", 2: "device_settings", 3: "user_profile",
    4: "hrm_profile", 5: "sdm_profile", 6: "bike_profile", 7: "zones_target",
    8: "hr_zone", 9: "power_zone", 10: "met_zone", 12: "sport", 15: "goal",
    18: "session", 19: "lap", 20: "record", 21: "event", 23: "device_info",
    26: "workout", 27: "workout_step", 28: "schedule", 30: "weight_scale",
    31: "course", 32: "course_point", 33: "totals", 34: "activity",
    35: "software", 37: "file_capabilities", 38: "mesg_capabilities",
    39: "field_capabilities", 49: "file_creator", 51: "blood_pressure",
    53: "speed_zone", 55: "monitoring", 72: "training_file", 78: "hrv",
    80: "ant_rx", 81: "ant_tx", 82: "ant_channel_id", 101: "length",
    103: "monitoring_info", 105: "pad", 106: "slave_device",
    127: "connectivity", 128: "weather_conditions", 129: "weather_alert",
    131: "cadence_zone", 132: "hr", 142: "segment_lap", 145: "memo_glob",
    148: "segment_id", 149: "segment_leaderboard_entry", 150: "segment_point",
    151: "segment_file", 158: "workout_session", 159: "watchface_settings",
    160: "gps_metadata", 161: "camera_event", 162: "timestamp_correlation",
    164: "gyroscope_data", 165: "accelerometer_data",
    167: "three_d_sensor_calibration", 169: "video_frame", 174: "obdii_data",
    177: "nmea_sentence", 178: "aviation_attitude", 184: "video",
    185: "video_title", 186: "video_description", 187: "video_clip",
    188: "ohr_settings", 200: "exd_screen_configuration",
    201: "exd_data_field_configuration", 202: "exd_data_concept_configuration",
    206: "field_description", 207: "developer_data_id",
    208: "magnetometer_data", 209: "barometer_data",
    210: "one_d_sensor_calibration", 211: "monitoring_hr_data",
    216: "time_in_zone", 225: "set", 227: "stress_level", 229: "max_met_data",
    258: "dive_settings", 259: "dive_gas", 262: "dive_alarm",
    264: "exercise_title", 268: "dive_summary", 269: "spo2_data",
    275: "sleep_level", 285: "jump", 290: "beat_intervals",
    297: "respiration_rate", 302: "hsa_accelerometer_data",
    304: "hsa_step_data", 305: "hsa_spo2_data", 306: "hsa_stress_data",
    307: "hsa_respiration_data", 308: "hsa_heart_rate_data", 312: "split",
    313: "split_summary", 314: "hsa_body_battery_data", 315: "hsa_event",
    317: "climb_pro", 319: "tank_update", 323: "tank_summary",
    346: "sleep_assessment", 370: "hrv_status_summary", 371: "hrv_value",
    372: "raw_bbi", 375: "device_aux_battery_info",
    376: "hsa_gyroscope_data", 387: "chrono_shot_session",
    388: "chrono_shot_data", 389: "hsa_configuration_data",
    393: "dive_apnea_alarm", 398: "skin_temp_overnight",
    409: "hsa_wrist_temperature_data",
    # community-identified (Gadgetbridge), not in the public profile
    140: "physiological_metrics (community)",
    273: "sleep_data_info (community)",
    274: "sleep_data_raw (community)",
    397: "skin_temp_raw (community)",
}

FIELDS = {
    0: {0: "type", 1: "manufacturer", 2: "product", 3: "serial_number",
        4: "time_created", 5: "number", 8: "product_name"},
    18: {253: "timestamp", 2: "start_time", 5: "sport", 6: "sub_sport",
         7: "total_elapsed_time", 8: "total_timer_time", 9: "total_distance",
         11: "total_calories", 16: "avg_heart_rate", 17: "max_heart_rate"},
    20: {253: "timestamp", 0: "position_lat", 1: "position_long",
         2: "altitude", 3: "heart_rate", 4: "cadence", 5: "distance",
         6: "speed", 7: "power", 13: "temperature", 73: "enhanced_speed",
         78: "enhanced_altitude"},
    23: {253: "timestamp", 0: "device_index", 1: "device_type",
         2: "manufacturer", 3: "serial_number", 4: "product",
         5: "software_version", 27: "product_name"},
    55: {253: "timestamp", 0: "device_index", 1: "calories", 2: "distance",
         3: "cycles", 4: "active_time", 5: "activity_type",
         6: "activity_subtype", 7: "activity_level", 19: "active_calories",
         24: "current_activity_type_intensity", 26: "timestamp_16",
         27: "heart_rate", 29: "duration_min", 31: "ascent", 32: "descent",
         33: "moderate_activity_minutes", 34: "vigorous_activity_minutes"},
    103: {253: "timestamp", 0: "local_timestamp", 1: "activity_type",
          3: "cycles_to_distance", 4: "cycles_to_calories",
          5: "resting_metabolic_rate"},
    211: {253: "timestamp", 0: "resting_heart_rate",
          1: "current_day_resting_heart_rate"},
    227: {0: "stress_level_value", 1: "stress_level_time",
          3: "body_energy (community: Body Battery)"},
    269: {253: "timestamp", 0: "reading_spo2", 1: "reading_confidence",
          2: "mode"},
    275: {253: "timestamp", 0: "sleep_level"},
    297: {253: "timestamp", 0: "respiration_rate"},
    346: {0: "combined_awake_score", 1: "awake_time_score",
          2: "awakenings_count_score", 3: "deep_sleep_score",
          4: "sleep_duration_score", 5: "light_sleep_score",
          6: "overall_sleep_score", 7: "sleep_quality_score",
          8: "sleep_recovery_score", 9: "rem_sleep_score",
          10: "sleep_restlessness_score", 11: "awakenings_count",
          14: "interruptions_score", 15: "average_stress_during_sleep"},
    370: {253: "timestamp", 0: "weekly_average", 1: "last_night_average",
          2: "last_night_5_min_high", 3: "baseline_low_upper",
          4: "baseline_balanced_lower", 5: "baseline_balanced_upper",
          6: "status"},
    371: {253: "timestamp", 0: "value"},
}

FILE_TYPES = {
    1: "device", 2: "settings", 3: "sport", 4: "activity", 5: "workout",
    6: "course", 7: "schedules", 9: "weight", 10: "totals", 11: "goals",
    14: "blood_pressure", 15: "monitoring_a", 20: "activity_summary",
    28: "monitoring_daily", 32: "monitoring_b", 34: "segment",
    35: "segment_list", 40: "exd_configuration",
    # community-identified subtypes seen on Garmin watches
    49: "sleep (community)", 68: "hrv_status (community)",
}

MANUFACTURERS = {1: "garmin", 15: "dynastream", 255: "development"}

# The signals the app's canonical model wants, and where a Garmin FIT file
# carries them: (label, global message, field, note).
SIGNALS = [
    ("HR per menit", 55, 27, "monitoring.heart_rate"),
    ("HR istirahat", 211, 0, "monitoring_hr_data.resting_heart_rate"),
    ("Langkah / siklus", 55, 3, "monitoring.cycles (langkah = cycles untuk jalan/lari)"),
    ("Kalori aktif", 55, 19, "monitoring.active_calories"),
    ("Menit intensitas", 55, 33, "monitoring.moderate/vigorous_activity_minutes"),
    ("Stres 0-100", 227, 0, "stress_level.stress_level_value (<0 = tidak ada bacaan)"),
    ("Body Battery", 227, 3, "stress_level.body_energy (nama dari komunitas)"),
    ("SpO2", 269, 0, "spo2_data.reading_spo2"),
    ("Respirasi", 297, 0, "respiration_rate.respiration_rate (/100 = napas/menit)"),
    ("Tahap tidur", 275, 0, "sleep_level.sleep_level"),
    ("Skor tidur", 346, 6, "sleep_assessment.overall_sleep_score"),
    ("HRV ringkasan malam", 370, 1, "hrv_status_summary.last_night_average (/128 = ms)"),
    ("HRV nilai", 371, 0, "hrv_value.value"),
    ("Interval beat-to-beat", 78, 0, "hrv.time (aktivitas)"),
    ("Physiological metrics", 140, None, "physiological_metrics (VO2max dll., komunitas)"),
    ("Rekaman aktivitas", 20, 3, "record.heart_rate"),
    ("GPS aktivitas", 20, 0, "record.position_lat"),
]


def message_name(num: int) -> str:
    return MESSAGES.get(num, f"unknown_{num}")


# Fields with the same meaning in every message.
COMMON_FIELDS = {253: "timestamp", 254: "message_index", 250: "part_index"}


# Wellness messages whose every field we want named: an unnamed field in one of
# these is a reverse-engineering target. Other public messages (session, lap,
# record, ...) are documented in the FIT SDK and are not listed field by field.
HEALTH_MESSAGES = {55, 103, 211, 227, 269, 275, 297, 346, 370, 371}


def is_documented_elsewhere(msg: int) -> bool:
    """A public-profile message outside HEALTH_MESSAGES."""
    name = MESSAGES.get(msg)
    return name is not None and "(community)" not in name and msg not in HEALTH_MESSAGES


def field_name(msg: int, num: int) -> str:
    return FIELDS.get(msg, {}).get(num) or COMMON_FIELDS.get(num) or f"field_{num}"
