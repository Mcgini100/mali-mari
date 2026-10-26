import '../../domain/models.dart';

/// Categories that match how money actually moves in Zimbabwe.
/// Shona and Ndebele names are a first pass and need native-speaker review
/// (see docs/LOCALISATION.md).
const defaultCategories = <Category>[
  Category(id: 'groceries', nameEn: 'Groceries', nameSn: 'Zvekudya', nameNd: 'Ukudla', icon: 'groceries', kind: CategoryKind.expense, sortOrder: 0),
  Category(id: 'transport', nameEn: 'Transport', nameSn: 'Zvekufamba', nameNd: 'Ezokuhamba', icon: 'transport', kind: CategoryKind.expense, sortOrder: 1),
  Category(id: 'airtime', nameEn: 'Airtime & data', nameSn: 'Airtime nedata', nameNd: 'I-airtime ledatha', icon: 'airtime', kind: CategoryKind.expense, sortOrder: 2),
  Category(id: 'rent', nameEn: 'Rent', nameSn: 'Rendi', nameNd: 'Irenti', icon: 'rent', kind: CategoryKind.expense, sortOrder: 3),
  Category(id: 'school', nameEn: 'School fees', nameSn: 'Fizi dzechikoro', nameNd: 'Imali yesikolo', icon: 'school', kind: CategoryKind.expense, sortOrder: 4),
  Category(id: 'electricity', nameEn: 'ZESA tokens', nameSn: 'Magetsi (ZESA)', nameNd: 'Ugesi (ZESA)', icon: 'electricity', kind: CategoryKind.expense, sortOrder: 5),
  Category(id: 'water_council', nameEn: 'Water & rates', nameSn: 'Mvura nekanzuru', nameNd: 'Amanzi lekhansili', icon: 'water', kind: CategoryKind.expense, sortOrder: 6),
  Category(id: 'church', nameEn: 'Church & tithe', nameSn: 'Chechi nechegumi', nameNd: 'Isonto leshumi', icon: 'church', kind: CategoryKind.expense, sortOrder: 7),
  Category(id: 'family', nameEn: 'Family support', nameSn: 'Kubatsira mhuri', nameNd: 'Ukusekela imuli', icon: 'family', kind: CategoryKind.expense, sortOrder: 8),
  Category(id: 'fees', nameEn: 'Mobile money fees', nameSn: 'Machaji eEcoCash', nameNd: 'Izindleko ze-EcoCash', icon: 'fees', kind: CategoryKind.expense, sortOrder: 9),
  Category(id: 'health', nameEn: 'Health', nameSn: 'Hutano', nameNd: 'Impilo', icon: 'health', kind: CategoryKind.expense, sortOrder: 10),
  Category(id: 'eating_out', nameEn: 'Eating out', nameSn: 'Kudyira kunze', nameNd: 'Ukudlela ngaphandle', icon: 'eating_out', kind: CategoryKind.expense, sortOrder: 11),
  Category(id: 'mukando', nameEn: 'Mukando & savings', nameSn: 'Mukando nekuchengeta', nameNd: 'Umukando lokulondoloza', icon: 'savings', kind: CategoryKind.expense, sortOrder: 12),
  Category(id: 'other', nameEn: 'Other', nameSn: 'Zvimwe', nameNd: 'Okunye', icon: 'other', kind: CategoryKind.expense, sortOrder: 13),
  Category(id: 'salary', nameEn: 'Salary', nameSn: 'Muhoro', nameNd: 'Iholo', icon: 'salary', kind: CategoryKind.income, sortOrder: 20),
  Category(id: 'side_hustle', nameEn: 'Side hustle', nameSn: 'Bhizinesi diki', nameNd: 'Ibhizinisi elincane', icon: 'side_hustle', kind: CategoryKind.income, sortOrder: 21),
  Category(id: 'remittance', nameEn: 'From diaspora', nameSn: 'Kubva kunze kwenyika', nameNd: 'Okuvela phesheya', icon: 'remittance', kind: CategoryKind.income, sortOrder: 22),
  Category(id: 'income_other', nameEn: 'Other income', nameSn: 'Imwe mari inopinda', nameNd: 'Enye imali engenayo', icon: 'income_other', kind: CategoryKind.income, sortOrder: 23),
  Category(id: 'cash_out', nameEn: 'Cash out', nameSn: 'Kubvisa mari', nameNd: 'Ukukhipha imali', icon: 'cash_out', kind: CategoryKind.transfer, sortOrder: 30),
];
