const fs = require('fs');

const path = '/Users/charles/side-projects/Moneko/moneko-mobile/lib/features/home/presentation/constants/category_constants.dart';
const file = fs.readFileSync(path, 'utf8');

const categoryGroupsMatch = file.match(/const Map<String, List<String>> categoryGroups = {([\s\S]*?)};/);
if (categoryGroupsMatch) {
  console.log('Found categoryGroups in category_constants.dart:');
  console.log(categoryGroupsMatch[1].trim());
} else {
  console.log('categoryGroups not found in category_constants.dart');
}
