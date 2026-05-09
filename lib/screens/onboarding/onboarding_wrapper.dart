import 'package:flutter/material.dart';
import 'onboarding1_screen.dart';
import 'onboarding2_screen.dart';
import 'onboarding3_screen.dart';
import 'onboarding4_screen.dart';

class OnboardingWrapper extends StatefulWidget {
  const OnboardingWrapper({super.key});

  @override
  State<OnboardingWrapper> createState() => _OnboardingWrapperState();
}

class _OnboardingWrapperState extends State<OnboardingWrapper> {
  final PageController _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _controller,
        children: [
          Onboarding1Screen(controller: _controller),
          Onboarding2Screen(controller: _controller),
          Onboarding3Screen(controller: _controller),
          Onboarding4Screen(controller: _controller),
        ],
      ),
    );
  }
}
