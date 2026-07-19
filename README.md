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

## 初期実装

SwiftUI + AppKitでmacOS常駐アクセサリの土台を作ります。
OpenAI APIキーがある場合はResponses APIへ接続し、ない場合はローカルの仮応答でUIを確認できます。

```bash
export OPENAI_API_KEY="your_api_key_here"
swift run "伺か再現プロジェクト"
```

## 入力コマンド

- `検索: キーワード` でブラウザ検索
- `起動: Safari` のように入力してアプリ起動
- 通常の文章はキャラクターへの相談として扱う

## キャラクター画像

画像は `Sources/UkagakaReproductionProject/Resources/Characters/` に置きます。
初期設定では以下の名前を探します。

- `character_a_neutral.png`
- `character_a_happy.png`
- `character_a_angry.png`
- `character_a_sad.png`
- `character_a_surprised.png`
- `character_b_neutral.png`
- `character_b_happy.png`
- `character_b_angry.png`
- `character_b_sad.png`
- `character_b_surprised.png`

画像がない場合は仮のシルエット表示になります。

## GitHub Actions

`.github/workflows/swift.yml` でSwiftPMビルドを確認します。
