class AppStoreReview {
  final String id;
  final int rating;
  final String title;
  final String body;
  final String reviewerNickname;
  final String createdDate;
  final String territory;

  const AppStoreReview({
    required this.id,
    required this.rating,
    required this.title,
    required this.body,
    required this.reviewerNickname,
    required this.createdDate,
    required this.territory,
  });
}

// App Store rating to display in header
const double kAppStoreRating = 4.8;
const int kTotalReviewCount = 17;

// Hardcoded 5-star reviews - REAL REVIEWS FROM APP STORE
const List<AppStoreReview> appStoreReviews = [
  AppStoreReview(
    id: "review-001",
    rating: 5,
    title: "Strong AI analysis",
    body:
        "The AI scenario planning is superb, he will analysis according to your pocket sizing and give you the best suggestion and planning for you. This really helped those who dont know proper financial planning. Strongly recommended!",
    reviewerNickname: "Sameulchee",
    createdDate: "2026-02-08T10:30:00-08:00",
    territory: "MYS",
  ),
  AppStoreReview(
    id: "review-002",
    rating: 5,
    title: "Simple and easy to use",
    body:
        "Really enjoy using this app so far. It makes tracking shared expenses simple and stress-free, and the AI features save a lot of time. The interface is clean and easy to use, and great for daily spending and splitting costs with friends.",
    reviewerNickname: "Sarah SNi",
    createdDate: "2026-02-04T14:22:00-08:00",
    territory: "MYS",
  ),
  AppStoreReview(
    id: "review-003",
    rating: 5,
    title: "Beta User to Live Access!!",
    body:
        "I'm so excited since Moneko is live on AppStore now, Been using in Testflight. It's so easy to add Income/Expenses and even Family Sharing or Group Sharing, The best one is Add via WhatsApp Features!!",
    reviewerNickname: "Dato Wafiy Aziz",
    createdDate: "2026-02-04T09:15:00-08:00",
    territory: "MYS",
  ),
  AppStoreReview(
    id: "review-004",
    rating: 5,
    title: "Really good budgeting app!",
    body:
        "I try this app bcz of the cute cat icon and since it offers free trial, but I ended up staying bcz it's actually amazing!! The interface is super clean and simple, makes tracking my expenses super easy and it also offers some other features. Really recommend this app if you wanna manage your money with small amount of price!!",
    reviewerNickname: "MilMayr",
    createdDate: "2026-02-03T16:45:00-08:00",
    territory: "MYS",
  ),
  AppStoreReview(
    id: "review-005",
    rating: 5,
    title: "Web Android iOS app with WhatsApp integration !!!!",
    body:
        "This is only budgeting app that has all And they all are well synced. Developers actually listened and updated. They added many of my requests into this app. It's group of developers working on this project and they all know what they are doing. Widgets are nice too. My roommates and I used the sharing expenses experience through this app and never had any problem with it.",
    reviewerNickname: "AcE",
    createdDate: "2026-02-02T11:20:00-08:00",
    territory: "MYS",
  ),
  AppStoreReview(
    id: "review-006",
    rating: 5,
    title: "Smart AI and integration",
    body:
        "The processing speed of AI is incredibly fast and it was able to capture all the details, nice work",
    reviewerNickname: "Usnsbsb",
    createdDate: "2026-02-02T13:10:00-08:00",
    territory: "MYS",
  ),
  AppStoreReview(
    id: "review-007",
    rating: 5,
    title: "Quite impressive already, looking forward to enrichments",
    body:
        "It's impressive how much is already packed into this first version. The UI is really well-done and makes the app easy to navigate. Being able to pull a list of transactions from one screenshot is a handy feature, and I like that I can set up different spaces with so many category options. The graphs are also a nice way to see a quick overview of my spending. It's a strong foundation and I'm interested to see how it develops.",
    reviewerNickname: "utsavdotpro",
    createdDate: "2026-01-31T15:30:00-08:00",
    territory: "USA",
  ),
  AppStoreReview(
    id: "review-008",
    rating: 5,
    title: "Very useful app",
    body: "Very useful app. Design is minimalist just I like.",
    reviewerNickname: "Ankitkumar Singh",
    createdDate: "2026-02-09T04:01:00-08:00",
    territory: "IND",
  ),
  AppStoreReview(
    id: "review-009",
    rating: 5,
    title: "Great app with AI features",
    body:
        "Great app to have AI write down all of your expenses. My one complaint is there are free trials and lifetime subscription but no free option. Also the developer is really enthusiastic to bring new features and improvements to the app.",
    reviewerNickname: "Chris Mayberry",
    createdDate: "2026-02-06T03:23:00-08:00",
    territory: "USA",
  ),
  AppStoreReview(
    id: "review-010",
    rating: 5,
    title: "Perfect WhatsApp integration",
    body:
        "it is really the app i was looking for. instead of choosing a category and etc.. i can just type a message and its AI automatically does everything. can also share a voice & image. Surprising feature was the whatsapp integration. It reqlly is a awesome featute, dear developers pls polish this feature without any bugs and u will the lead app in this category. I am from india we use whatsapp as the primary communication app so this will be awesome. i am already a lifetime subscriber thank u",
    reviewerNickname: "ram prasad",
    createdDate: "2026-02-03T03:31:00-08:00",
    territory: "IND",
  ),
  AppStoreReview(
    id: "review-011",
    rating: 5,
    title: "The best app to manage money",
    body:
        "The best app to manage money. By the help of AI, I can understand the availability of future planning. The important is I can easily insert the minor expense by voice or image instead of type in one by one, save my effort",
    reviewerNickname: "Giotto",
    createdDate: "2026-02-02T01:36:00-08:00",
    territory: "MYS",
  ),
  AppStoreReview(
    id: "review-012",
    rating: 5,
    title: "Perfect for shared expense tracking",
    body:
        "Moneko is the suitable app for shared expense tracking. Unlike traditional budgeting tools that require perfect inputs, Moneko embraces the messy reality of life. Log expenses through text, voice, photos, or chat messages, and the smart AI organizes everything automatically. Roommates, can add an expense once, and everyone stays in sync. No complicated forms are needed—simply type, speak, or snap a photo. Moneko categorizes spending, keeps totals",
    reviewerNickname: "conekt conekt",
    createdDate: "2026-01-30T12:14:00-08:00",
    territory: "MYS",
  ),
  AppStoreReview(
    id: "review-013",
    rating: 5,
    title: "Really cool auto-categorization",
    body:
        "The app is really nice. I am using it for my expenses. Really cool feature is that it automatically sorts them into appropriate categories when you type / use voice. Another feature is voice captu",
    reviewerNickname: "Dr. Rahul Mishra",
    createdDate: "2026-01-29T21:05:00-08:00",
    territory: "IND",
  ),
  AppStoreReview(
    id: "review-014",
    rating: 5,
    title: "Magnifique app en français ! Corrigez les petits bugs d'affichage",
    body:
        "Cette application gère parfaitement les dépenses partagées pour couples ou colocataires, avec saisie simple par voix, texte, photo ou WhatsApp, IA qui catégorise auto et budgets sync multi-devises. C'est comme un conseiller financier IA : demandez si vous pouvez acheter un ordinateur avant une date précise, et il planifie tout. L'interface true black mauve est top sur iPhone, et elle est en français complet (ajustez la fiche App Store). Bugs à fixer : À police système maximale, textes illisibles/chevauchés. Affichage coupé police agrandie (autres captures). Nom utilisateur illisible ; utilisez prénom. Écriture invisible en nommant espace. 5 étoiles malgré tout. Excellente app, améliorez l'accessibilité svp !",
    reviewerNickname: "Datura mon amour",
    createdDate: "2026-02-07T10:30:00-08:00",
    territory: "FRA",
  ),
  AppStoreReview(
    id: "review-015",
    rating: 5,
    title: "Tạm ổn",
    body:
        "Cũng khá hay, nhưng app còn 1 số case call api lỗi xong show nguyên cả json lỗi ra, cần cải thiện hơn",
    reviewerNickname: "Duongdev",
    createdDate: "2026-02-07T14:22:00-08:00",
    territory: "VNM",
  ),
  AppStoreReview(
    id: "review-016",
    rating: 5,
    title: "1st app that helps me actually keep track consistently",
    body: "Thanks for this great app",
    reviewerNickname: "WardAlakhras",
    createdDate: "2026-02-04T09:15:00-08:00",
    territory: "USA",
  ),
  AppStoreReview(
    id: "review-017",
    rating: 5,
    title: "Quản lý tài chính",
    body: "Ứng dụng rất tuyệt vờii, giúp quản lý chi tiêu và phân tích rõ ràng",
    reviewerNickname: "dqbao09",
    createdDate: "2026-02-03T16:45:00-08:00",
    territory: "VNM",
  ),
  AppStoreReview(
    id: "review-018",
    rating: 5,
    title: "Actively Developed",
    body:
        "This app actively receives updates, and the developer is extremely responsive over on Reddit. It's also a lot more budget friendly than other apps which charge exorbitant fees for anyone who doesn't have a lot of disposable income. There's even a lifetime plan for a fair price. My personal favorite thing though is that while it's not quite on par with other apps in terms of features like automation and syncing, it's moving very fast in that direction, and I have hope that it'll be a top option soon.",
    reviewerNickname: "Maple382",
    createdDate: "2026-03-14T12:00:00-08:00",
    territory: "USA",
  ),
  AppStoreReview(
    id: "review-019",
    rating: 5,
    title: "Envelope budgeting",
    body:
        "Really fantastic budgeting app — straightforward, easy to use and integrate, helpful. The interface is very natural and it all works very smoothly.",
    reviewerNickname: "User34862",
    createdDate: "2026-02-19T12:00:00-08:00",
    territory: "USA",
  ),
];
