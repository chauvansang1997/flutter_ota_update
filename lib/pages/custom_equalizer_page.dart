import 'package:flutter/material.dart';
import 'package:flutter_gaia/controlller/OtaServer.dart';
import 'package:flutter_gaia/utils/gaia/filter.dart';
import 'package:get/get.dart';

class CustomEqualizerPage extends StatefulWidget {
  const CustomEqualizerPage({super.key});

  @override
  State<CustomEqualizerPage> createState() => _CustomEqualizerPageState();
}

class _CustomEqualizerPageState extends State<CustomEqualizerPage> {
  @override
  void initState() {
    OtaServer.to.controllEqualizerError.listen((event) {
      if (event && mounted) {
        Get.back();
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    OtaServer.to.controllEqualizer = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Custom Equalizer Control Demo"),
      ),
      body: Obx(() {
        final masterGainValue =
            OtaServer.to.mBank.value.getMasterGain().positionValue;

        final masterGainBoundsLength =
            OtaServer.to.mBank.value.getMasterGain().boundsLength;

        final masterGainLabelMaxBound =
            OtaServer.to.mBank.value.getMasterGain().labelMaxBound;

        final masterGainLabelMinBound =
            OtaServer.to.mBank.value.getMasterGain().labelMinBound;

        final masterGainConfigure =
            OtaServer.to.mBank.value.getMasterGain().isConfigurable;

        final gainValue =
            OtaServer.to.mBank.value.getCurrentBand().getGain().positionValue;

        final gainBoundsLength =
            OtaServer.to.mBank.value.getCurrentBand().getGain().boundsLength;

        final gainLabelMaxBound =
            OtaServer.to.mBank.value.getCurrentBand().getGain().labelMaxBound;

        final gainLabelMinBound =
            OtaServer.to.mBank.value.getCurrentBand().getGain().labelMinBound;

        final gainConfigure =
            OtaServer.to.mBank.value.getCurrentBand().getGain().isConfigurable;

        final frequencyValue = OtaServer.to.mBank.value
            .getCurrentBand()
            .getFrequency()
            .positionValue;

        final frequencylabelMaxBound = OtaServer.to.mBank.value
            .getCurrentBand()
            .getFrequency()
            .labelMaxBound;

        final frequencylabelMinBound = OtaServer.to.mBank.value
            .getCurrentBand()
            .getFrequency()
            .labelMinBound;

        final frequencyBoundsLength = OtaServer.to.mBank.value
            .getCurrentBand()
            .getFrequency()
            .boundsLength;

        final frequencyConfigure = OtaServer.to.mBank.value
            .getCurrentBand()
            .getFrequency()
            .isConfigurable;

        final qualityValue = OtaServer.to.mBank.value
            .getCurrentBand()
            .getQuality()
            .positionValue;

        final qualityLabelMaxBound = OtaServer.to.mBank.value
            .getCurrentBand()
            .getQuality()
            .labelMaxBound;

        final qualityLabelMinBound = OtaServer.to.mBank.value
            .getCurrentBand()
            .getQuality()
            .labelMinBound;

        final qualityBoundsLength =
            OtaServer.to.mBank.value.getCurrentBand().getQuality().boundsLength;

        final qualityConfigure = OtaServer.to.mBank.value
            .getCurrentBand()
            .getFrequency()
            .isConfigurable;

        final isLoading = OtaServer.to.isConnecting.value ||
            !OtaServer.to.isRegisterNotification.value ||
            OtaServer.to.isSendingRequest.value;

        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Text("Master Gain: $masterGainValue"),

                  // if (masterGainConfigure)
                  _buildSliderWithLabels(
                    title: 'Master Gain',
                    value: masterGainValue.toDouble(),
                    min: 0,
                    max: masterGainBoundsLength.toDouble(),
                    onChanged: (value) {
                      OtaServer.to.onMaterGain(value.toInt());
                    },
                    minLabel: masterGainLabelMinBound,
                    maxLabel: masterGainLabelMaxBound,
                  ),

                  const SizedBox(height: 16),

                  // if (gainConfigure)
                  _buildSliderWithLabels(
                    title: 'Gain',
                    value: gainValue.toDouble(),
                    min: 0,
                    max: gainBoundsLength.toDouble(),
                    onChanged: (value) {
                      OtaServer.to.onGainChange(value.toInt());
                    },
                    minLabel: gainLabelMinBound,
                    maxLabel: gainLabelMaxBound,
                  ),

                  const SizedBox(height: 16),

                  // if (frequencyConfigure)
                  _buildSliderWithLabels(
                    title: 'Frequency',
                    value: frequencyValue.toDouble(),
                    min: 0,
                    max: frequencyBoundsLength.toDouble(),
                    onChanged: (value) {
                      OtaServer.to.onFrequencyChange(value.toInt());
                    },
                    minLabel: frequencylabelMinBound,
                    maxLabel: frequencylabelMaxBound,
                  ),

                  const SizedBox(height: 16),

                  // if (qualityConfigure)
                  _buildSliderWithLabels(
                    title: 'Quality',
                    value: qualityValue.toDouble(),
                    min: 0,
                    max: qualityBoundsLength.toDouble(),
                    onChanged: (value) {
                      OtaServer.to.onQualityChange(value.toInt());
                    },
                    minLabel: qualityLabelMinBound,
                    maxLabel: qualityLabelMaxBound,
                  ),

                  const SizedBox(height: 16),

                  _buildListBands(),

                  const SizedBox(height: 16),

                  _buildFilterList(),

                  const SizedBox(height: 16),
                ],
              ),
            ),
            if (isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildListBands() {
    return Wrap(
      children: List.generate(5, (index) {
        return _BandItem(
          index: index,
          isSelected: index == OtaServer.to.mBank.value.currentBandIndex,
          onBandChange: (index) {
            OtaServer.to.selectBand(index);
          },
        );
      }),
    );

    // return SizedBox(
    //   height: 100,
    //   child: ListView.builder(
    //     scrollDirection: Axis.horizontal,
    //     itemCount: 5,
    //     itemBuilder: (context, index) {
    //       return _BandItem(
    //         index: index,
    //         isSelected: index == OtaServer.to.mBank.value.currentBandIndex,
    //       );
    //     },
    //   ),
    // );
  }

  Widget _buildFilterList() {
    return Wrap(
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.start,
      spacing: 10,
      runSpacing: 10,
      children: List.generate(Filter.values.length, (index) {
        return _FilterTypeItem(
          filter: Filter.values[index],
          isSelected: Filter.values[index] ==
              OtaServer.to.mBank.value.getCurrentBand().getFilter(),
          onFilterSelected: (filter) {
            final currentBandIndex = OtaServer.to.mBank.value.currentBandIndex;
            OtaServer.to.setFilter(currentBandIndex, filter, true);
          },
        );
      }),
    );
  }

  // Helper method to build a slider with min/max labels
  Widget _buildSliderWithLabels({
    required String title,
    required double value,
    required double min,
    required double max,
    required Function(double) onChanged,
    required String minLabel,
    required String maxLabel,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Text(title),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Slider(
                value: value < min
                    ? min
                    : value > max
                        ? max
                        : value,
                min: min > max ? max : min,
                max: max,
                divisions: 100,
                onChanged: onChanged,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(minLabel),
                    Text(maxLabel),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BandItem extends StatelessWidget {
  const _BandItem({
    required this.index,
    required this.isSelected,
    this.onBandChange,
  });

  final int index;
  final bool isSelected;
  final Function(int index)? onBandChange;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(60),
      child: IntrinsicWidth(
        child: Material(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(60),
          ),
          color: isSelected ? Colors.orange : Colors.white,
          child: InkWell(
            onTap: () {
              onBandChange?.call(index);
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: Text(
                  'Band $index',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterTypeItem extends StatelessWidget {
  const _FilterTypeItem({
    required this.filter,
    required this.isSelected,
    this.onFilterSelected,
  });

  final Filter filter;
  final bool isSelected;
  final Function(Filter filter)? onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(60),
      child: IntrinsicWidth(
        child: Material(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(60),
          ),
          color: isSelected ? Colors.orange : Colors.white,
          child: InkWell(
            onTap: () {
              onFilterSelected?.call(filter);
            },
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Center(
                child: Text(
                  filter.name,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
