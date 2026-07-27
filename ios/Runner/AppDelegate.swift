import Flutter
import UIKit
import AppIntents

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    // 遅延・リトライ付きで MethodChannel をバインドする
    self.setupMethodChannelWithRetry(attempts: 0)

    return result
  }

  // FlutterViewControllerの準備ができるまで遅延・リトライする安全な登録ロジック
  private func setupMethodChannelWithRetry(attempts: Int) {
    let rootVC = window?.rootViewController ?? UIApplication.shared.windows.first?.rootViewController
    
    if let controller = rootVC as? FlutterViewController {
      print("DEBUG_NATIVE: FlutterViewController found at attempt \(attempts). Registering MethodChannel...")
      let aiChannel = FlutterMethodChannel(name: "com.example.mpt_simulator/native_ai",
                                                binaryMessenger: controller.binaryMessenger)
      
      aiChannel.setMethodCallHandler({
        [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        guard let self = self else { return }
        if call.method == "sharePortfolio" {
          guard let args = call.arguments as? [String: Any],
                let json = args["json"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "json is required", details: nil))
            return
          }
          
          UserDefaults.standard.set(json, forKey: "shared_portfolio_data")
          print("DEBUG_NATIVE: Shared portfolio data written to UserDefaults.")
          result(nil)
        } else if call.method == "analyzePortfolio" {
          guard let args = call.arguments as? [String: Any],
                let json = args["json"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "json is required", details: nil))
            return
          }
          
          let advice = self.generateLocalAiAdvice(jsonString: json)
          result(advice)
        } else {
          result(FlutterMethodNotImplemented)
        }
      })
    } else {
      print("DEBUG_NATIVE: Attempt \(attempts) failed. rootVC is nil or not FlutterViewController.")
      if attempts < 15 { // 最大15回 (約1.5秒間) リトライする (100ms 間隔)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
          self?.setupMethodChannelWithRetry(attempts: attempts + 1)
        }
      } else {
        print("DEBUG_NATIVE: Giving up on registering MethodChannel. RootVC remained nil.")
      }
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // オンデバイスAI (ローカル分析) のプレミアムシミュレータ (初心者向け・超パーソナライズ化)
  private func generateLocalAiAdvice(jsonString: String) -> String {
    guard let data = jsonString.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
          let portfolio = json["portfolio"] as? [String: Any],
          let risk = portfolio["risk"] as? Double,
          let expectedReturn = portfolio["expectedReturn"] as? Double,
          let sharpeRatio = portfolio["sharpeRatio"] as? Double else {
      return "ポートフォリオのデータ解析に失敗しました。"
    }

    // アセット情報と比率を取得
    let assets = json["assets"] as? [[String: Any]] ?? []
    let weights = portfolio["weights"] as? [String: Double] ?? [:]
    
    // 比率が一番高いアセットを特定
    var maxAssetId = ""
    var maxAssetWeight = 0.0
    var maxAssetName = ""
    for asset in assets {
      if let id = asset["id"] as? String,
         let name = asset["name"] as? String,
         let w = weights[id], w > maxAssetWeight {
        maxAssetWeight = w
        maxAssetId = id
        maxAssetName = name
      }
    }

    let riskPercent = String(format: "%.1f%%", risk * 100)
    let returnPercent = String(format: "%.1f%%", expectedReturn * 100)
    let sharpeString = String(format: "%.2f", sharpeRatio)
    let maxAssetWeightPercent = String(format: "%.0f%%", maxAssetWeight * 100)

    var advice = "【iOS On-Device AI プレミアム診断 💡】\n\n"
    advice += "■ あなたの資産構成の特徴分析:\n"
    advice += "・予想リターン (年利目安): \(returnPercent)\n"
    advice += "・値動きのブレ幅 (リスク): \(riskPercent)\n"
    advice += "・運用の効率性 (シャープ比): \(sharpeString)\n"
    if !maxAssetName.isEmpty && maxAssetWeight > 0.01 {
      advice += "・比率が最も高いアセット: \(maxAssetName) (\(maxAssetWeightPercent))\n"
    }
    advice += "\n"

    advice += "■ AIからの個別アドバイス:\n"
    
    if maxAssetWeight > 0.55 {
      // 1つのアセットに集中投資している場合
      advice += "⚠️ 【特定資産への依存度がやや高めです】\n現在、アロケーションの中で「\(maxAssetName)」が \(maxAssetWeightPercent) と過半数を占めています。特定の市場に頼りすぎているため、分散効果（リスク低減効果）が十分に働いていません。\n👉 アドバイス: \(maxAssetName) の一部（15%〜20%）を、「日本債券」や「米国債券」のような安定資産、または「金 (Gold)」に振り分けることで、将来期待できるリターンをあまり落とさずに、ポートフォリオ全体のリスク（ブレ幅）を劇的に下げることができます。\n\n"
    } else if risk < 0.05 {
      // 保守的な場合
      advice += "🛡️ 【手堅い守り重視の組み合わせです】\n元本割れのリスクが非常に低く抑えられており、安全面は優秀です。しかし、インフレ（物価上昇）によってお金の実質的な価値が目減りしてしまう弱点があります。\n👉 アドバイス: もし少しだけリターンを伸ばしたいなら、日本債券や米国債券の一部（10%程度）を「米国株式」や「日本株式」などの成長資産に移してみてください。リスクを最小限に抑えたまま、運用効率（シャープ比）をさらに高められます。\n\n"
    } else if risk < 0.12 {
      // バランス型の場合
      advice += "⚖️ 【非常に美しいバランスの取れた組み合わせです】\nリスクとリターンのバランスが最も効率的な『黄金比』に近い構成です。複数の資産（株・債券・金）が綺麗に散らばっているため、特定の市場が大きく荒れても、他の資産がクッションになって全体を支えてくれます。\n👉 アドバイス: このまま積立投資を続けるのが最も堅実です。年に1回ほど比率がズレていないか確認し、元の比率に戻す作業（リバランス）を行うだけで、高いパフォーマンスを維持できます。\n\n"
    } else {
      // 高リスク型の場合
      advice += "🚀 【リターン最大化を狙うアグレッシブな構成です】\n株式が中心の積極的な配分で、好景気には大きな値上がりが期待できます。しかし、不景気（大暴落時）には資産が一時的に大きく減るショックを伴います。\n👉 アドバイス: 『卵を一つのカゴに盛るな』という格言の通り、アセットの中に「日本債券」や「金 (Gold)」などの値動きの異なるクッション資産を合計で15%程度混ぜてください。これにより、長期で見たときのリターンを下げることなく、一時的な暴落時の下落幅（リスク）だけをぐっと和らげることができます。\n\n"
    }

    if sharpeRatio < 0.45 {
      let hasUsStock = (weights["us_stock"] ?? 0) > 0.05
      let hasEmStock = (weights["em_stock"] ?? 0) > 0.05
      
      advice += "⚠️ 【投資効率（シャープ比）を高めるコツ】\n"
      if hasUsStock && hasEmStock {
        advice += "現在、米国株式と新興国株式が同時に多く入っています。これらは値動きの連動性（相関係数 0.7）が高いため、組み合わせても「互いに補い合う効果（分散効果）」があまり期待できません。株とは全く別の動きをする『日本債券（相関係数 -0.1）』や『金』を適量組み入れることで、シャープ比は劇的に向上します。"
      } else {
        advice += "アセットの中に「値動きのタイミングがズレる資産（例: 株式に対しての債券、通貨に対しての金）」をもっと意識して組み合わせてみてください。同じリターン水準を保ちながら、ムダなリスクだけを削ぎ落とすことができます。"
      }
    } else {
      advice += "✨ 【組み合わせの投資効率は抜群です】\n資産同士の相関（値動きのズレ）がうまく機能しており、現代ポートフォリオ理論の『分散効果』が最大限に発揮されています。極めて洗練された組み合わせです。"
    }
    
    advice += "\n\n(Apple Intelligence 連携済み - iOSのSiriに「MPT Simulatorで今のポートフォリオを分析して」と話しかけることで、この最新の分析内容をSiriが音声で詳しく解説します)"

    return advice
  }
}

@available(iOS 16.0, *)
struct PortfolioEntity: AppEntity {
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "ポートフォリオ"
  
  var id: String
  var expectedReturn: Double
  var risk: Double
  var sharpeRatio: Double
  var allocationText: String
  
  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(
      title: "\(id)",
      subtitle: "予想リターン: \(String(format: "%.1f%%", expectedReturn * 100)) / リスク: \(String(format: "%.1f%%", risk * 100))"
    )
  }
  
  static var defaultQuery = PortfolioQuery()
}

@available(iOS 16.0, *)
struct PortfolioQuery: EntityQuery {
  func entities(for ids: [PortfolioEntity.ID]) async throws -> [PortfolioEntity] {
    return try await fetchAllEntities().filter { ids.contains($0.id) }
  }
  
  func suggestedEntities() async throws -> [PortfolioEntity] {
    return try await fetchAllEntities()
  }
  
  private func fetchAllEntities() async throws -> [PortfolioEntity] {
    guard let jsonString = UserDefaults.standard.string(forKey: "shared_portfolio_data"),
          let data = jsonString.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
          let portfolio = json["portfolio"] as? [String: Any],
          let risk = portfolio["risk"] as? Double,
          let expectedReturn = portfolio["expectedReturn"] as? Double,
          let sharpeRatio = portfolio["sharpeRatio"] as? Double else {
      return []
    }
    
    var allocationParts: [String] = []
    if let assets = json["assets"] as? [[String: Any]],
       let weights = portfolio["weights"] as? [String: Double] {
      for asset in assets {
        if let id = asset["id"] as? String,
           let name = asset["name"] as? String,
           let w = weights[id], w > 0 {
          allocationParts.append("\(name): \(Int(w * 100))%")
        }
      }
    }
    
    let entity = PortfolioEntity(
      id: "マイポートフォリオ",
      expectedReturn: expectedReturn,
      risk: risk,
      sharpeRatio: sharpeRatio,
      allocationText: allocationParts.joined(separator: ", ")
    )
    return [entity]
  }
}

@available(iOS 16.0, *)
struct AnalyzePortfolioIntent: AppIntent {
  static var title: LocalizedStringResource = "ポートフォリオを分析する"
  static var description = IntentDescription("現在の MPT ポートフォリオのデータを分析し、Apple Intelligence がアドバイスを提示します。")
  
  static var parameterSummary: some ParameterSummary {
    Summary("マイポートフォリオを分析します")
  }
  
  @MainActor
  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    guard let jsonString = UserDefaults.standard.string(forKey: "shared_portfolio_data"),
          let data = jsonString.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
          let portfolio = json["portfolio"] as? [String: Any],
          let risk = portfolio["risk"] as? Double,
          let expectedReturn = portfolio["expectedReturn"] as? Double,
          let sharpeRatio = portfolio["sharpeRatio"] as? Double else {
      
      return .result(
        value: "ポートフォリオデータがまだ設定されていません。アプリを起動してアロケーション比率を設定してください。",
        dialog: "分析できるポートフォリオが見つかりませんでした。アプリを一度起動してアロケーション比率を調整してください。"
      )
    }
    
    let riskPercent = String(format: "%.1f%%", risk * 100)
    let returnPercent = String(format: "%.1f%%", expectedReturn * 100)
    let sharpeString = String(format: "%.2f", sharpeRatio)
    
    var siriSpeech = "現在のポートフォリオは、予想リターンが\(returnPercent)、価格のブレ幅を示すリスクが\(riskPercent)、投資効率を示すシャープ比が\(sharpeString)です。"
    
    if risk < 0.05 {
      siriSpeech += "🛡️ 手堅い守り重視の配分です。安定していますが、インフレ対策として株式比率を少し増やしてみるのもおすすめです。"
    } else if risk < 0.12 {
      siriSpeech += "⚖️ 非常にバランスが取れた素晴らしい配分です。世界中に綺麗に分散されているため、このまま積立投資を続けるのが最適です。"
    } else {
      siriSpeech += "🚀 値上がり重視の積極的な配分です。少し安定性を高めたい場合は、日本債券や金を10%ほど追加して分散効果を得ることを検討してください。"
    }
    
    return .result(
      value: siriSpeech,
      dialog: IntentDialog(stringLiteral: siriSpeech)
    )
  }
}

@available(iOS 16.0, *)
struct MPTAppShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: AnalyzePortfolioIntent(),
      phrases: [
        "\(.applicationName)でポートフォリオを分析",
        "\(.applicationName)で診断を実行",
        "\(.applicationName)でリスクを調べる"
      ],
      shortTitle: "ポートフォリオ診断",
      systemImageName: "chart.pie.fill"
    )
  }
}
