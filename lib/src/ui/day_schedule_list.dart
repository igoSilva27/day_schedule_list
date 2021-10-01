import 'package:flutter/material.dart';

import '../models/interval_range.dart';
import '../models/minute_interval.dart';
import 'day_schedule_list_extensions.dart';
import 'interval_containers/appointment_container.dart';
import 'interval_containers/unavailable_interval_container.dart';
import 'time_of_day_widget.dart';
import '../helpers/time_of_day_extensions.dart';

typedef AppointmentWidgetBuilder<K extends IntervalRange> = Widget Function(
    BuildContext context, K appointment);

typedef UpdateAppointDuration<K extends IntervalRange> = Future<bool> Function(
    K appointment, IntervalRange newInterval);

class DayScheduleList<T extends IntervalRange> extends StatefulWidget {
  const DayScheduleList({
    required this.referenceDate,
    required this.unavailableIntervals,
    required this.appointments,
    required this.updateAppointDuration,
    required this.appointmentBuilder,
    this.hourHeight = 100.0,
    Key? key,
  }) : super(key: key);

  final DateTime referenceDate;
  final List<IntervalRange> unavailableIntervals;
  final List<T> appointments;
  final UpdateAppointDuration<T> updateAppointDuration;
  final AppointmentWidgetBuilder<T> appointmentBuilder;
  final double hourHeight;

  @override
  _DayScheduleListState<T> createState() => _DayScheduleListState<T>();
}

class _DayScheduleListState<S extends IntervalRange>
    extends State<DayScheduleList<S>> with DayScheduleListMethods {
  final MinuteInterval minimumMinuteInterval = MinuteInterval.one;
  final MinuteInterval appointmentMinimumDuration = MinuteInterval.thirty;

  double get minimumMinuteIntervalHeight =>
      (widget.hourHeight * minimumMinuteInterval.numberValue.toDouble()) / 60.0;

  late double timeOfDayWidgetHeight;

  List<ScheduleTimeOfDay> validTimesList = [];

  final GlobalKey _validTimesListColumnKey = GlobalKey();

  @override
  void initState() {
    timeOfDayWidgetHeight = 10 * minimumMinuteIntervalHeight;
    _populateValidTimesList();
    super.initState();
  }

  @override
  void didUpdateWidget(covariant DayScheduleList<S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    //if(oldWidget.unavailableIntervals != widget.unavailableIntervals) {
    _populateValidTimesList();
    //}
  }

  @override
  Widget build(BuildContext context) {
    const baseInsetVertical = 20.0;
    final timeOfDayWidgetHeight = 10 * minimumMinuteIntervalHeight;
    final insetVertical = baseInsetVertical + timeOfDayWidgetHeight / 2.0;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 2,
        ),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Column(
              key: _validTimesListColumnKey,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(
                  height: baseInsetVertical,
                ),
                ..._buildTimeOfDayWidgetList(),
                const SizedBox(
                  height: baseInsetVertical,
                ),
              ],
            ),
            const Positioned(
              top: 0,
              left: 35,
              bottom: 0,
              child: VerticalDivider(),
            ),
            ..._buildUnavailableIntervalsWidgetList(
              insetVertical: insetVertical,
            ),
            ..._buildAppointmentsWidgetList(
              insetVertical: insetVertical,
            ),
          ],
        ),
      ),
    );
  }

  void _populateValidTimesList() {
    validTimesList = [];
    final verifyUnavailableIntervals = widget.unavailableIntervals.isNotEmpty;
    for (var item = 0; item < 25; item++) {
      final hasTimeBefore = item > 0;
      final TimeOfDay time =
          TimeOfDay(hour: item == 24 ? 23 : item, minute: item == 24 ? 59 : 0);
      if (verifyUnavailableIntervals) {
        final IntervalRange first = widget.unavailableIntervals.first;
        final IntervalRange last = widget.unavailableIntervals.last;

        final belongsToFirst = first.belongsToRange(time);
        final belongsToLast = last.belongsToRange(time);

        if (hasTimeBefore) {
          final beforeDateTime =
              DateTime(DateTime.now().year, 1, 1, time.hour, time.minute)
                  .subtract(const Duration(hours: 1));
          final timeBefore = TimeOfDay.fromDateTime(beforeDateTime);
          final timeBeforeBelongsToFirst = first.belongsToRange(timeBefore);
          final timeBeforeBelongsToLast = last.belongsToRange(timeBefore);
          if (timeBeforeBelongsToFirst && !belongsToFirst) {
            final dateTimeToAdd = DateTime(
                    DateTime.now().year, 1, 1, first.end.hour, first.end.minute)
                .add(Duration(minutes: minimumMinuteInterval.numberValue));
            final timeOfDayToAdd = TimeOfDay.fromDateTime(dateTimeToAdd);
            if (time.toMinutes - timeOfDayToAdd.toMinutes >
                minimumMinuteInterval.numberValue) {
              validTimesList.add(
                _belongsToInternalUnavailableRange(timeOfDayToAdd)
                    ? ScheduleTimeOfDay.unavailable(time: timeOfDayToAdd)
                    : ScheduleTimeOfDay.available(time: timeOfDayToAdd),
              );
            }
          } else if (!timeBeforeBelongsToLast && belongsToLast) {
            final dateTimeToAdd = DateTime(DateTime.now().year, 1, 1,
                    last.start.hour, last.start.minute)
                .subtract(Duration(minutes: minimumMinuteInterval.numberValue));
            final timeOfDayToAdd = TimeOfDay.fromDateTime(dateTimeToAdd);
            if (time.toMinutes - timeOfDayToAdd.toMinutes >
                minimumMinuteInterval.numberValue) {
              validTimesList.add(
                _belongsToInternalUnavailableRange(timeOfDayToAdd)
                    ? ScheduleTimeOfDay.unavailable(time: timeOfDayToAdd)
                    : ScheduleTimeOfDay.available(time: timeOfDayToAdd),
              );
            }
          }
        }

        if (!belongsToFirst && !belongsToLast) {
          validTimesList.add(
            _belongsToInternalUnavailableRange(time)
                ? ScheduleTimeOfDay.unavailable(time: time)
                : ScheduleTimeOfDay.available(time: time),
          );
        }
      } else {
        validTimesList.add(
          _belongsToInternalUnavailableRange(time)
              ? ScheduleTimeOfDay.unavailable(time: time)
              : ScheduleTimeOfDay.available(time: time),
        );
      }
    }
  }

  List<Widget> _buildTimeOfDayWidgetList() {
    List<Widget> items = [];
    for (var index = 0; index < validTimesList.length; index++) {
      final hasNextItem = index < validTimesList.length - 1;
      final ScheduleTimeOfDay scheduleTime = validTimesList[index];
      final item = TimeOfDayWidget(
          scheduleTime: scheduleTime, height: timeOfDayWidgetHeight);
      if (hasNextItem) {
        final nextTime = validTimesList[index + 1];
        final timeInMinutes = scheduleTime.time.toMinutes;
        final nextTimeInMinutes = nextTime.time.toMinutes;
        final intervalInMinutes = nextTimeInMinutes - timeInMinutes;
        final numberOfStepsBetween =
            intervalInMinutes / minimumMinuteInterval.numberValue;
        final spaceBetween =
            numberOfStepsBetween * minimumMinuteIntervalHeight -
                timeOfDayWidgetHeight;
        if (spaceBetween >= 0) {
          items.addAll([
            item,
            SizedBox(
              height: spaceBetween,
            ),
          ]);
        }
      } else {
        items.add(item);
      }
    }
    return items;
  }

  List<UnavailableIntervalContainer> _buildUnavailableIntervalsWidgetList(
      {required double insetVertical}) {
    final List<IntervalRange> unavailableSublist =
        widget.unavailableIntervals.length >= 3
            ? widget.unavailableIntervals
                .sublist(1, widget.unavailableIntervals.length - 1)
            : [];
    return unavailableSublist.map((IntervalRange interval) {
      return UnavailableIntervalContainer(
        interval: interval,
        position: calculateItemRangePosition(
          itemRange: interval,
          minimumMinuteInterval: minimumMinuteInterval,
          minimumMinuteIntervalHeight: minimumMinuteIntervalHeight,
          insetVertical: insetVertical,
          firstValidTime: validTimesList.first,
        ),
      );
    }).toList();
  }

  List<AppointmentContainer> _buildAppointmentsWidgetList(
      {required double insetVertical}) {
    List<AppointmentContainer> items = [];
    List<S> appointments = widget.appointments;
    List<IntervalRange> unavailableIntervals = widget.unavailableIntervals;
    for (var index = 0; index < appointments.length; index++) {
      final interval = appointments[index];
      items.add(AppointmentContainer(
        updateHeightStep: minimumMinuteIntervalHeight,
        position: calculateItemRangePosition(
          itemRange: interval,
          minimumMinuteInterval: minimumMinuteInterval,
          minimumMinuteIntervalHeight: minimumMinuteIntervalHeight,
          insetVertical: insetVertical,
          firstValidTime: validTimesList.first,
        ),
        canUpdateHeightTo: (newHeight) => canUpdateHeightOfInterval<S>(
          index: index,
          appointments: appointments,
          newHeight: newHeight,
          unavailableIntervals: unavailableIntervals,
          validTimesList: validTimesList,
          minimumMinuteInterval: minimumMinuteInterval,
          appointmentMinimumDuration: appointmentMinimumDuration,
          minimumMinuteIntervalHeight: minimumMinuteIntervalHeight,
        ),
        onUpdateHeightEnd: (double newHeight) =>
            _updateAppointIntervalForNewHeight(
          appointment: interval,
          newHeight: newHeight,
        ),
        canUpdateTopTo: (double newTop) => canUpdateTopOfInterval(
          index: index,
          newTop: newTop,
          insetVertical: insetVertical,
          appointments: appointments,
          validTimesList: validTimesList,
          contentHeight: _validTimesListColumnKey.currentContext?.size?.height ?? 0,
          minimumMinuteInterval: minimumMinuteInterval,
          minimumMinuteIntervalHeight: minimumMinuteIntervalHeight
        ),
        onUpdateTopEnd: (double newTop) => _updateAppointIntervalForNewTop(
          index: index,
          appointments: appointments,
          newTop: newTop,
          insetVertical: insetVertical,
        ),
        child: widget.appointmentBuilder(context, interval),
      ));
    }
    return items;
  }

  Future<bool> _updateAppointIntervalForNewHeight({
    required S appointment,
    required double newHeight,
  }) async {
    final newInterval = calculateItervalRangeFor(
        start: appointment.start,
        newDurationHeight: newHeight,
        minimumMinuteInterval: minimumMinuteInterval,
        minimumMinuteIntervalHeight: minimumMinuteIntervalHeight);
    return await widget.updateAppointDuration(appointment, newInterval);
  }

  Future<bool> _updateAppointIntervalForNewTop({
    required int index,
    required List<S> appointments,
    required double newTop,
    required double insetVertical,
  }) async {
    final appointment = appointments[index];
    final newInterval = calculateItervalRangeForNewTop(
        range: appointment,
        newTop: newTop,
        firstValidTime: validTimesList.first.time,
        insetVertical: insetVertical,
        minimumMinuteInterval: minimumMinuteInterval,
        minimumMinuteIntervalHeight: minimumMinuteIntervalHeight);

    final intersectsOtherAppointment = widget.appointments.any((element) {
      return element != appointment && newInterval.intersects(element);
    });

    final intersectsSomeUnavailableRange = widget.unavailableIntervals.any((element) {
      return newInterval.intersects(element);
    });

    if(intersectsOtherAppointment || intersectsSomeUnavailableRange) {
      setState(() {});
      return false;
    }

    final success = await widget.updateAppointDuration(appointment, newInterval);
    return success;
  }

  bool _belongsToInternalUnavailableRange(TimeOfDay time) {
    final List<IntervalRange> internalUnavailableIntervals =
        widget.unavailableIntervals.length >= 3
            ? widget.unavailableIntervals
                .sublist(1, widget.unavailableIntervals.length - 1)
            : [];
    return internalUnavailableIntervals
        .any((element) => element.belongsToRange(time));
  }
}
