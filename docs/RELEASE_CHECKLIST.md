# リリースチェックリスト

## ベータ配布

- `swift test` が成功する
- `Scripts/build-app.sh` と `Scripts/verify-app.sh` が成功する
- ZIPとDMGを別ユーザー環境で展開し、初回設定が開く
- 表示、非表示、設定保存、再起動、検索、アプリ起動を確認する
- APIキー設定時に会話でき、未設定時はローカル応答になる
- ログイン時起動を有効化し、再ログイン後に起動する
- アンインストールでログイン項目、設定、Keychain項目、アプリ本体が削除される

## 正式配布前

- Apple Developer ProgramのDeveloper ID Application証明書で署名する
- `notarytool` でAppleの公証を通し、`stapler` でチケットを添付する
- 配布するキャラクター画像とソースコードのライセンスを確定する
- OpenAI APIへ送信する情報と料金負担をリリースノートにも明記する
- バージョンタグ `vX.Y.Z` を作成し、Release workflowのZIPとDMGを実機確認する

署名IDは `CODE_SIGN_IDENTITY`、バージョンは `VERSION`、ビルド番号は `BUILD_NUMBER` として `Scripts/build-app.sh` に渡せます。現在のGitHub Actions成果物はアドホック署名のため、初回はFinderから右クリックして「開く」が必要になる場合があります。
