/*
  Build:
    flutter pub add record
    flutter build apk --release
    ls -la build/app/outputs/apk/release/
 */
import 'dart:io';         // Needed to exit the app
import 'dart:async';
import 'package:flutter/material.dart';
// https://pub.dev/packages/record
// API: https://pub.dev/documentation/record/latest/record/record-library.html
import 'package:record/record.dart';

void main() {
  runApp(const MaterialApp(home: MicPage()));
}

class MicPage extends StatefulWidget {
  const MicPage({super.key});

  @override
  State<MicPage> createState() => _MicPageState();
}

class _MicPageState extends State<MicPage> {
  AudioRecorder myRecording = AudioRecorder();
  Timer? timer;
  final String _start = "Start";
  final String _stop = "Stop";

  int count = 0;
  int delay = 30;
  double volume = 0.0;
  double minVolume = -30.0;
  String btnText = "";
  bool running = false;

  reset() {
    running = false;
    count = 0;
  }

  void toggleRunning() {
    if (running) {
      myRecording.stop();
      running = false;
    } else {
      running = true;
      startRecording();
    }
  }

  startTimer() async {
    timer = Timer.periodic(
        Duration(milliseconds: delay),
        (timer) {
          running ? updateVolume() : timer.cancel();
        }
      );
  }

  updateVolume() async {
    Amplitude ampl = await myRecording.getAmplitude();
    if (ampl.current > minVolume) {
      setState(() {
        volume = (ampl.current - minVolume) / minVolume;
        // The volume that is being displayed is multiplied by 100!
        // And the number is negative!
  // ToDo: make the threshold configurable:
        if (volume < -.5) {
          count++;
        }
      });
    }
  }

  int volume0to(int maxVolumeToDisplay) {
    return (volume * maxVolumeToDisplay).round().abs();
  }

  Future<bool> startRecording() async {
    if (await myRecording.hasPermission()) {
      if (!await myRecording.isRecording()) {
        await myRecording.startStream(const RecordConfig(encoder: AudioEncoder.aacLc,),);
      }
      startTimer();
      return true;
    } else {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    btnText = running ? _stop : _start;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clapper Counter'),
        foregroundColor: Colors.yellow,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: () {
              setState(() {
                reset();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app_rounded),
            onPressed: () { exit(0); },
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10.0, 50.0, 10.0, 0.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter:',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.blue,
                    inactiveTrackColor: Colors.lightBlue,
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Container(
                    width: 340,
                    child: Slider(
                        value: minVolume,
                        min: -100,
                        max: 0,
                        divisions: 100,
                        label: minVolume.toString(),
                        onChanged: (double value) {
                          setState(() {
                            minVolume = value;
                          });
                        }
                      ),
                  )
                ),
              ],
            ),
          ),
          Text("${minVolume.toInt()}",
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold
              )
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10.0, 50.0, 10.0, 0.0),
            child:
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Delay:',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.blue,
                        inactiveTrackColor: Colors.lightBlue,
                        overlayShape: SliderComponentShape.noOverlay,
                      ),
                      child: Container(
                        width: 340,
                        child: Slider(
                            value: delay.toDouble(),
                            min: 1,
                            max: 100,
                            divisions: 100,
                            label: delay.toString(),
                            onChanged: (double value) {
                              setState(() {
                                delay = value.toInt();
                                // We need to create a new timer:
                                running = false;
                                startTimer();
                              });
                            }
                        ),
                      )
                  ),
                ],
              ),
          ),
          Text("$delay ms",
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold
              )
          ),
          Padding(
              padding: const EdgeInsets.fromLTRB(0.0, 100.0, 0.0, 0.0),
              child:
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Count:\n$count",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 50,
                        fontWeight: FontWeight.bold
                      )
                  ),
                ],
              ),
          ),
          Padding(
              padding: const EdgeInsets.fromLTRB(0.0, 100.0, 0.0, 0.0),
              child:
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: running ? Colors.redAccent : Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 50,
                          vertical: 20
                      ),
                      textStyle: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.normal,
                      ),
                  ),
                  onPressed: () {
                    setState(() {
                      toggleRunning();
                    });
                  },
                  child: Text(btnText),
              ),
          ),
        ],
      )
    );
  }
}