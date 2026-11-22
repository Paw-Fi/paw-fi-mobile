// Standalone worker adapter for the same ARB catalogs used by Flutter.
import 'dart:convert';
import 'dart:io';

class WorkerLocale {
  WorkerLocale(this.tag);
  final String tag;
  String get languageCode => tag.split('_').first;
  String? get countryCode => tag.contains('_') ? tag.split('_').last : null;
  @override
  String toString() => tag;
}

class AppLocalizations {
  AppLocalizations(this._messages);
  final Map<String, dynamic> _messages;
  static final _catalogs = <String, AppLocalizations>{};
  static Iterable<WorkerLocale> get supportedLocales =>
      _catalogs.keys.map(WorkerLocale.new);
  static void load(Directory directory) {
    Map<String, dynamic> read(String tag) =>
        jsonDecode(File('${directory.path}/app_$tag.arb').readAsStringSync())
            as Map<String, dynamic>;
    final tags = directory
        .listSync()
        .map((file) =>
            RegExp(r'/app_([a-zA-Z_]+)\.arb$').firstMatch(file.path)?.group(1))
        .whereType<String>()
        .toList()
      ..sort();
    final fallback = read('en');
    for (final tag in tags) {
      _catalogs[tag] = AppLocalizations({
        ...fallback,
        if (tag.contains('_')) ...read(tag.split('_').first),
        ...read(tag)
      });
    }
  }

  String get account => _messages['account'] as String;
  String get amount => _messages['amount'] as String;
  String get category => _messages['category'] as String;
  String get categoryAdsMarketing =>
      _messages['categoryAdsMarketing'] as String;
  String get categoryAppliances => _messages['categoryAppliances'] as String;
  String get categoryBabySupplies =>
      _messages['categoryBabySupplies'] as String;
  String get categoryBankFees => _messages['categoryBankFees'] as String;
  String get categoryBarsDrinks => _messages['categoryBarsDrinks'] as String;
  String get categoryBeautyCosmetics =>
      _messages['categoryBeautyCosmetics'] as String;
  String get categoryBikeScooter => _messages['categoryBikeScooter'] as String;
  String get categoryBonus => _messages['categoryBonus'] as String;
  String get categoryBooksStudyMaterials =>
      _messages['categoryBooksStudyMaterials'] as String;
  String get categoryBusinessExpenses =>
      _messages['categoryBusinessExpenses'] as String;
  String get categoryCarInsurance =>
      _messages['categoryCarInsurance'] as String;
  String get categoryCarParts => _messages['categoryCarParts'] as String;
  String get categoryCarRental => _messages['categoryCarRental'] as String;
  String get categoryCarRepairs => _messages['categoryCarRepairs'] as String;
  String get categoryCashback => _messages['categoryCashback'] as String;
  String get categoryCharity => _messages['categoryCharity'] as String;
  String get categoryChildcare => _messages['categoryChildcare'] as String;
  String get categoryCleaningSupplies =>
      _messages['categoryCleaningSupplies'] as String;
  String get categoryClothingShoes =>
      _messages['categoryClothingShoes'] as String;
  String get categoryCloudStorage =>
      _messages['categoryCloudStorage'] as String;
  String get categoryCoffeeTea => _messages['categoryCoffeeTea'] as String;
  String get categoryCollectibles =>
      _messages['categoryCollectibles'] as String;
  String get categoryCommunityEvents =>
      _messages['categoryCommunityEvents'] as String;
  String get categoryConcertsEvents =>
      _messages['categoryConcertsEvents'] as String;
  String get categoryCoursesClasses =>
      _messages['categoryCoursesClasses'] as String;
  String get categoryCoworkingSpace =>
      _messages['categoryCoworkingSpace'] as String;
  String get categoryCraftsArt => _messages['categoryCraftsArt'] as String;
  String get categoryDating => _messages['categoryDating'] as String;
  String get categoryDebtPayments =>
      _messages['categoryDebtPayments'] as String;
  String get categoryDentalCare => _messages['categoryDentalCare'] as String;
  String get categoryElectricity => _messages['categoryElectricity'] as String;
  String get categoryEnvironmentalGreen =>
      _messages['categoryEnvironmentalGreen'] as String;
  String get categoryExamsCertificates =>
      _messages['categoryExamsCertificates'] as String;
  String get categoryEyeCare => _messages['categoryEyeCare'] as String;
  String get categoryFines => _messages['categoryFines'] as String;
  String get categoryFitnessGym => _messages['categoryFitnessGym'] as String;
  String get categoryFlights => _messages['categoryFlights'] as String;
  String get categoryFoodAndDrinks =>
      _messages['categoryFoodAndDrinks'] as String;
  String get categoryFreelanceIncome =>
      _messages['categoryFreelanceIncome'] as String;
  String get categoryFuelGas => _messages['categoryFuelGas'] as String;
  String get categoryFurniture => _messages['categoryFurniture'] as String;
  String get categoryGamesApps => _messages['categoryGamesApps'] as String;
  String get categoryGifts => _messages['categoryGifts'] as String;
  String get categoryGovernmentServices =>
      _messages['categoryGovernmentServices'] as String;
  String get categoryGroceries => _messages['categoryGroceries'] as String;
  String get categoryHealthInsurance =>
      _messages['categoryHealthInsurance'] as String;
  String get categoryHeatingGas => _messages['categoryHeatingGas'] as String;
  String get categoryHobbies => _messages['categoryHobbies'] as String;
  String get categoryHomeDecor => _messages['categoryHomeDecor'] as String;
  String get categoryHomeInsurance =>
      _messages['categoryHomeInsurance'] as String;
  String get categoryHomeOffice => _messages['categoryHomeOffice'] as String;
  String get categoryHomeRepairs => _messages['categoryHomeRepairs'] as String;
  String get categoryHomeSecurity =>
      _messages['categoryHomeSecurity'] as String;
  String get categoryHomeServices =>
      _messages['categoryHomeServices'] as String;
  String get categoryHotels => _messages['categoryHotels'] as String;
  String get categoryHouseholdSupplies =>
      _messages['categoryHouseholdSupplies'] as String;
  String get categoryIncome => _messages['categoryIncome'] as String;
  String get categoryInsurance => _messages['categoryInsurance'] as String;
  String get categoryInterestIncome =>
      _messages['categoryInterestIncome'] as String;
  String get categoryInternet => _messages['categoryInternet'] as String;
  String get categoryInvestments => _messages['categoryInvestments'] as String;
  String get categoryKidsActivities =>
      _messages['categoryKidsActivities'] as String;
  String get categoryKidsClothing =>
      _messages['categoryKidsClothing'] as String;
  String get categoryLaundryDryCleaning =>
      _messages['categoryLaundryDryCleaning'] as String;
  String get categoryLicensingFees =>
      _messages['categoryLicensingFees'] as String;
  String get categoryLifeInsurance =>
      _messages['categoryLifeInsurance'] as String;
  String get categoryLoanPayments =>
      _messages['categoryLoanPayments'] as String;
  String get categoryLuggageGear => _messages['categoryLuggageGear'] as String;
  String get categoryMedicalCare => _messages['categoryMedicalCare'] as String;
  String get categoryMentalHealth =>
      _messages['categoryMentalHealth'] as String;
  String get categoryMiscellaneous =>
      _messages['categoryMiscellaneous'] as String;
  String get categoryMortgage => _messages['categoryMortgage'] as String;
  String get categoryMoviesShows => _messages['categoryMoviesShows'] as String;
  String get categoryMovingCosts => _messages['categoryMovingCosts'] as String;
  String get categoryMusicStreaming =>
      _messages['categoryMusicStreaming'] as String;
  String get categoryOther => _messages['categoryOther'] as String;
  String get categoryParking => _messages['categoryParking'] as String;
  String get categoryPartiesHosting =>
      _messages['categoryPartiesHosting'] as String;
  String get categoryPassportVisaFees =>
      _messages['categoryPassportVisaFees'] as String;
  String get categoryPension => _messages['categoryPension'] as String;
  String get categoryPersonalCare =>
      _messages['categoryPersonalCare'] as String;
  String get categoryPetBoardingSitting =>
      _messages['categoryPetBoardingSitting'] as String;
  String get categoryPetFood => _messages['categoryPetFood'] as String;
  String get categoryPetGrooming => _messages['categoryPetGrooming'] as String;
  String get categoryPetInsurance =>
      _messages['categoryPetInsurance'] as String;
  String get categoryPetMedicine => _messages['categoryPetMedicine'] as String;
  String get categoryPetSupplies => _messages['categoryPetSupplies'] as String;
  String get categoryPetTreats => _messages['categoryPetTreats'] as String;
  String get categoryPharmacy => _messages['categoryPharmacy'] as String;
  String get categoryPhoneBill => _messages['categoryPhoneBill'] as String;
  String get categoryPostDelivery =>
      _messages['categoryPostDelivery'] as String;
  String get categoryProfessionalServices =>
      _messages['categoryProfessionalServices'] as String;
  String get categoryPublicTransport =>
      _messages['categoryPublicTransport'] as String;
  String get categoryRefunds => _messages['categoryRefunds'] as String;
  String get categoryReligiousSpiritual =>
      _messages['categoryReligiousSpiritual'] as String;
  String get categoryRent => _messages['categoryRent'] as String;
  String get categoryRentalIncome =>
      _messages['categoryRentalIncome'] as String;
  String get categoryRentersInsurance =>
      _messages['categoryRentersInsurance'] as String;
  String get categoryRestaurants => _messages['categoryRestaurants'] as String;
  String get categorySalary => _messages['categorySalary'] as String;
  String get categorySavings => _messages['categorySavings'] as String;
  String get categorySchoolSupplies =>
      _messages['categorySchoolSupplies'] as String;
  String get categorySnacks => _messages['categorySnacks'] as String;
  String get categorySoftwareTools =>
      _messages['categorySoftwareTools'] as String;
  String get categorySpaMassage => _messages['categorySpaMassage'] as String;
  String get categorySportsClubs => _messages['categorySportsClubs'] as String;
  String get categorySportsExercise =>
      _messages['categorySportsExercise'] as String;
  String get categoryStorage => _messages['categoryStorage'] as String;
  String get categorySupplements => _messages['categorySupplements'] as String;
  String get categoryTakeoutDelivery =>
      _messages['categoryTakeoutDelivery'] as String;
  String get categoryTaxes => _messages['categoryTaxes'] as String;
  String get categoryTaxiRideApps =>
      _messages['categoryTaxiRideApps'] as String;
  String get categoryTherapy => _messages['categoryTherapy'] as String;
  String get categoryTips => _messages['categoryTips'] as String;
  String get categoryTolls => _messages['categoryTolls'] as String;
  String get categoryToysGames => _messages['categoryToysGames'] as String;
  String get categoryTransfers => _messages['categoryTransfers'] as String;
  String get categoryTransportation =>
      _messages['categoryTransportation'] as String;
  String get categoryTrashRecycling =>
      _messages['categoryTrashRecycling'] as String;
  String get categoryTravel => _messages['categoryTravel'] as String;
  String get categoryTravelActivities =>
      _messages['categoryTravelActivities'] as String;
  String get categoryTravelInsurance =>
      _messages['categoryTravelInsurance'] as String;
  String get categoryUncategorized =>
      _messages['categoryUncategorized'] as String;
  String get categoryVetVisits => _messages['categoryVetVisits'] as String;
  String get categoryWater => _messages['categoryWater'] as String;
  String get categoryWorkSupplies =>
      _messages['categoryWorkSupplies'] as String;
  String get currency => _messages['currency'] as String;
  String get date => _messages['date'] as String;
  String get description => _messages['description'] as String;
  String get expense => _messages['expense'] as String;
  String get income => _messages['income'] as String;
  String get merchant => _messages['merchant'] as String;
  String get notes => _messages['notes'] as String;
  String get type => _messages['type'] as String;
}

AppLocalizations lookupAppLocalizations(WorkerLocale locale) =>
    AppLocalizations._catalogs[locale.tag]!;
