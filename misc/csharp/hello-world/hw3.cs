// string型の変数を宣言する
string aFriend = "Bill";
// aFriendの中身を後から変更（再代入）する
aFriend = "Maira";

string firstfriend = "Maria";
string secondfriend = "Steeve";

// 文字列を連結して出力する
Console.WriteLine($"Hello {firstfriend} and {secondfriend}!");

Console.WriteLine(@"C:\Users\Masaki\Desktop"); // @をつけると、\をエスケープシーケンスとして認識しない

// 文字列のLengthプロパティ？
Console.WriteLine($"The name has {firstfriend.Length} characters.");
Console.WriteLine($"The name has {secondfriend.Length} characters.");

//integer型の変数を宣言する(int)
//その後age = aaa;とすると文字列のためエラーとなる
int age = 10;
//age = aaaaa;　//エラーとなる。vscodeがエラーを教えてくれる

// Trim()メソッドの例
string greeting = "      Hello World!       ";
Console.WriteLine($"[{greeting}]");

string trimmedGreeting = greeting.TrimStart();
Console.WriteLine($"[{trimmedGreeting}]");

trimmedGreeting = greeting.TrimEnd();
Console.WriteLine($"[{trimmedGreeting}]");

trimmedGreeting = greeting.Trim();
Console.WriteLine($"[{trimmedGreeting}]");

string greeting2 = "Hello World!";
Console.WriteLine(greeting2.Replace("Hello", "Welcome"));

// 足し算
int a = 18;
int b = 5;
int c = a + b;
Console.WriteLine(c);

// 変数定義内で計算する例
// "c"はすでに定義されているため、再定義はできないが、再代入は可能
c = a * b * 10 / 2;
Console.WriteLine(c);

// WorkWithIntegers()というメソッドを定義して呼び出す
// 関数が前に出ているが、トップレベルステートメントとして整形されるため実行できる
WorkWithIntegers();

void WorkWithIntegers()
{
    int a = 18;
    int b = 6;
    int c = a + b;
    Console.WriteLine(c);


    // subtraction
    c = a - b;
    Console.WriteLine(c);

    // multiplication
    c = a * b;
    Console.WriteLine(c);

    // division
    c = a / b;
    Console.WriteLine(c);
}

// 整数同士の割り算で割り切れない例
int d = 18;
int e = 5;
int f = 18 / 5;
Console.WriteLine(f); // 3と出力される。整数同士の割り算は、結果も整数になるため、小数点以下が切り捨てられる。

// 小数点以下も扱えるdouble型で割り算を行う例
double g = 7;
double h = 5;
double i = g / h;
Console.WriteLine(i); // 1.4と出力される。double型は小数点以下も扱えるため、正確な結果が得られる。

// 整数型intの限界　MaxValueとMinValueプロパティを使用して、整数型の最大値と最小値を表示する例
int max = int.MaxValue;
int min = int.MinValue;
Console.WriteLine($"The range of integers is {min} to {max}");
Console.WriteLine($"最大値に1を足すと...: {max + 1}");

// 整数型long型の限界　MaxValueとMinValueプロパティを使用して、long型の最大値と最小値を表示する例
long maxLong = long.MaxValue;
long minLong = long.MinValue;
Console.WriteLine($"The range of long integers is {minLong} to {maxLong}");

int j = 7;
long k = 5;
long l = j + k; // int型のjはlong型に暗黙的に変換されてから、long型のkと足し算されるため、結果もlong型になる。
Console.WriteLine(l);

var m = 7; // varを使用して変数を宣言する例。mはint型として推論される。
var n = 5.0; // nはdouble型として推論される。
var o = m + n; // mはint型、nはdouble型のため、mはdouble型に暗黙的に変換されてから、double型のnと足し算されるため、結果もdouble型になる。
Console.WriteLine(o);

