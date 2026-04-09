class DispatchJobFitResult {
  final bool fits;
  final String? reason;

  const DispatchJobFitResult({
    required this.fits,
    this.reason,
  });

  const DispatchJobFitResult.ok()
      : fits = true,
        reason = null;

  const DispatchJobFitResult.fail(String this.reason) : fits = false;
}