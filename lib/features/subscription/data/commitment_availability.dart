const commitmentUnavailableCountries = {'US', 'SG', 'AU'};

bool isCommitmentAvailableForCountry(String? countryCode) {
  return !commitmentUnavailableCountries.contains(
    countryCode?.trim().toUpperCase(),
  );
}
