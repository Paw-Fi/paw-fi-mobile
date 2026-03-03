const fs = require('fs');
const path = '/Users/charles/side-projects/Moneko/moneko-mobile/lib/l10n/app_en.arb';
const data = JSON.parse(fs.readFileSync(path, 'utf8'));

const newKeys = {
  "categoryGroupLifeHome": "Life & Home",
  "categoryGroupTravelTransport": "Travel & Transport",
  "categoryGroupHealthWellness": "Health & Wellness",
  "categoryGroupKids": "Kids",
  "categoryGroupPets": "Pets",
  "categoryGroupWorkLearning": "Work & Learning",
  "categoryGroupFunSocial": "Fun & Social",
  "categoryGroupMoneyInOut": "Money In & Out",
  "categoryGroupCommunityServices": "Community & Services",
  "categoryGroupMisc": "Miscellaneous"
};

for (const [key, val] of Object.entries(newKeys)) {
  if (!data[key]) {
    data[key] = val;
  }
}

fs.writeFileSync(path, JSON.stringify(data, null, 2));
console.log('Fixed app_en.arb with group keys');
