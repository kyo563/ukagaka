# 伺か再現プロジェクト

2000年代に流行した「伺か」の体験を、ChatGPTを使った現代のmacOSデスクトップ常駐コンシェルジュとして再現するプロジェクトです。

このプロジェクトの開発はGitHubリポジトリ上で進めます。

## 目指す体験

- キャラクター2名がイラストでデスクトップに常駐する
- 時報や「今日は何の日」を知らせる
- 放置中に定期的な掛け合いで小噺を始める
- 吹き出しから直接検索する
- ブラウザや指定アプリを起動する
- キャラクター設定プロンプトだけで掛け合いや応答を生成する
- 喜怒哀楽などの表情差分をテキストに合わせて切り替える
- 共通立ち絵に顔・手・アイコン差分を重ねるレイヤー式スプライトに対応する

## 動作環境

- macOS 14 Sonoma以降
- Apple SiliconまたはIntel Mac
- ChatGPT連携を使う場合はOpenAI APIキーとAPI利用枠

ChatGPT Plusなどのサブスクリプションとは別に、OpenAI APIの利用設定が必要です。APIキー未設定でもローカル応答、検索、アプリ起動、時報、同梱の独り言を試せます。

## インストール

GitHub Actionsの `Build and test` からmacOS成果物を取得できます。ZIPを展開してアプリを `Applications` フォルダへ移すか、DMGを開いてアプリを `Applications` へドラッグします。

正式なDeveloper ID署名とApple公証を行う前のベータ成果物では、初回起動時にFinderでアプリを右クリックして「開く」を選ぶ必要がある場合があります。

ソースからローカル用アプリを作る場合:

```bash
Scripts/build-app.sh
Scripts/verify-app.sh
Scripts/install-local.sh
```

開発用に直接起動するだけなら `swift run "伺か再現プロジェクト"` も利用できます。APIキーは初回設定または設定画面で入力し、macOS Keychainへ保存します。

## 入力コマンド

- `検索: キーワード` でブラウザ検索
- `起動: Safari` のように入力してアプリ起動
- `今日は何の日` で内蔵の記念日情報を表示
- 通常の文章はキャラクターへの相談として扱う

## メニューと設定

- メニューバーから表示、非表示、設定、再起動、終了を実行できます
- デスクトップ上のキャラクターを右クリックしても同じ基本メニューを開けます
- 設定画面ではChatGPT連携、キャラクターの性格、モデル画像フォルダ、透過度、独り言の更新間隔、ログイン時自動起動を変更できます
- 設定画面から現在の設定を明示保存し、保存済み設定を再読み込みできます
- APIキー設定時の独り言は、2名の性格プロンプトに沿ってResponses APIで生成します

## 設定ライフサイクル

- 初回起動: 初回設定画面を表示し、APIキー、モデル名、キャラクター名、性格プロンプト、ログイン時自動起動を設定できます
- 通常設定: メニューバーまたは右クリックメニューから設定画面を開き、APIキー以外の変更内容をUserDefaultsに保存します
- APIキー: macOS Keychainに保存します。旧バージョンのUserDefaultsにあるキーは初回読み込み時に自動移行します
- 終了時: アプリ終了または再起動の直前に設定値を同期します
- 次回起動: UserDefaultsから保存済み設定を読み込み、キャラクター、画像フォルダ、透過度、独り言間隔、ChatGPT連携を復元します
- 常駐運用: 設定画面の「ログイン時に自動起動」を有効にすると、macOSのログイン項目として登録します。承認が必要な場合は設定画面からシステム設定を開けます

## アンインストール

メニューバー、右クリックメニュー、または設定画面から「アンインストール」を実行します。確認後、次をまとめて処理します。

- macOSのログイン時起動を解除
- UserDefaultsのアプリ設定を削除
- KeychainのOpenAI APIキーを削除
- アプリ本体をゴミ箱へ移動

設定画面で指定した外部モデル画像フォルダはユーザー所有データとして削除しません。

## OpenAI APIへ送信する情報

APIキー設定時は、入力した文章、直近6件の会話、2名の名前と性格プロンプト、指定モデル名をOpenAI Responses APIへ送信します。検索語とアプリ起動名はOpenAIへ送らず、Mac上で直接処理します。このアプリ独自の中継サーバーは使用しません。

## キャラクター画像

画像は `Sources/UkagakaReproductionProject/Resources/Characters/` に置きます。
配布後に別モデルへ差し替える場合は、設定画面の「モデル画像」で同じ構造の外部フォルダを指定します。
外部フォルダが指定されている場合はそちらを優先し、足りない画像はアプリ同梱画像へフォールバックします。

レイヤー式の画像がある場合は、そちらを優先して読み込みます。全レイヤーは同じキャンバスサイズ、同じ原点、透過PNGで書き出してください。

```text
Characters/
  character_a/
    base.png
    face_happy.png
    face_angry.png
    face_sad.png
    face_fun.png
    face_sleep.png
    hand_default.png
    hand_wave.png
    hand_point.png
    hand_think.png
    hand_emphasize.png
    hand_sleep.png
    icon_happy.png
    icon_angry.png
    icon_sad.png
    icon_fun.png
    icon_sleep.png

  character_b/
    base.png
    face_happy.png
    face_angry.png
    face_sad.png
    face_sleep.png
    icon_sad.png
    icon_sleep.png
```

### 推奨モデル画像仕様

- 形式: 透過PNG、sRGB、ファイル名は半角英数字・小文字・アンダースコアのみ
- 基準サイズ: 立ち絵キャラは縦1600から2400px程度、ぬいぐるみは縦1000から1600px程度
- キャンバス: 1キャラクター内の全レイヤーで幅・高さ・原点・足元の基準線を完全にそろえる
- 余白: 上下左右に8から12%程度の透明余白を残し、手やアイコンが切れないようにする
- 解像感: アプリ上では300px前後に縮小表示されるため、輪郭線と表情パーツは縮小後も読める太さにする
- 背景: 完全透過にし、白背景や影を焼き込まない。影が必要な場合は将来 `shadow.png` のような独立レイヤーにする
- 色: キャラクター本体は同じパレットで統一し、表情差分で色味や線幅が変わらないようにする
- レイヤー順: `base.png`、`hand_*.png`、`face_*.png`、`icon_*.png` の順に合成される
- `base.png`: 体、髪、服、固定小物など、表情や手の動きで変わらない部分
- `hand_*.png`: 腕や手だけを含む差分。不要なモデルでは省略可能
- `face_*.png`: 眉、口、目元などの表情差分。ぬいぐるみは瓶底眼鏡を崩さず、目が見えない前提を維持する
- `icon_*.png`: 涙、怒りマーク、`Zzz` など、顔を大きく変えずに感情を補う小物
- 容量目安: 1枚あたり5MB以下、1モデルパック全体で50MB以下を目標にする

配布後に差し替えるモデルパックは、任意の場所に次のような構成で置き、設定画面からそのフォルダを選択します。

```text
MyModelPack/
  character_a/
    base.png
    face_happy.png
    face_angry.png
    face_sad.png
    face_sleep.png
    hand_default.png
    hand_wave.png

  character_b/
    base.png
    face_angry.png
    face_sad.png
    face_sleep.png
    icon_sad.png
    icon_sleep.png
```

ぬいぐるみ側は喜の構図を `character_b/base.png` として固定し、怒は眉と口、哀は左レンズの水滴、寝は `Zzz` などのアイコンだけで表現する想定です。

レイヤー式画像がない場合は、従来の1枚絵ファイルへフォールバックします。

- `character_a_neutral.png`
- `character_a_happy.png`
- `character_a_angry.png`
- `character_a_sad.png`
- `character_a_fun.png`
- `character_a_sleep.png`
- `character_b_neutral.png`
- `character_b_happy.png`
- `character_b_angry.png`
- `character_b_sad.png`
- `character_b_sleep.png`

画像がない場合は仮のシルエット表示になります。

## ビルドとリリース

- `.github/workflows/swift.yml`: ビルド、テスト、アプリバンドル検証、ZIP/DMG成果物の作成
- `.github/workflows/release.yml`: 手動実行または `vX.Y.Z` タグからUniversal BinaryのGitHub Releaseを作成
- `docs/RELEASE_CHECKLIST.md`: ベータ配布と正式配布前の確認項目

正式配布ではDeveloper ID Application証明書による署名とApple公証が別途必要です。
