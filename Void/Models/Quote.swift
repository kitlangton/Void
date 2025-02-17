import Foundation

struct Quote: Identifiable, Equatable {
  let id = UUID()
  let text: String
  let source: String

  var lines: [String] {
    text.split(separator: "\n").map { String($0) }
  }
}

enum Quotes {
  static let all: [Quote] = [
    Quote(
      text: """
      Do not believe in something because it has been handed down through generations,
      Or because it is spoken by a great teacher.
      When you know for yourselves,
      That these things are wholesome and good,
      Then follow them.
      """,
      source: "Anguttara Nikaya 3.65"
    ),
    Quote(
      text: """
      Victory breeds hatred.
      The defeated live in pain.
      Happily the peaceful live,
      Giving up victory and defeat.
      """,
      source: "Dhammapada, Verse 201"
    ),
    Quote(
      text: """
      All conditioned things are impermanent —
      When one sees this with wisdom,
      One turns away from suffering.
      This is the path to purification.
      """,
      source: "Dhammapada, Verse 277"
    ),
    Quote(
      text: """
      Even as a mother protects with her life
      Her child, her only child,
      So with a boundless heart
      Should one cherish all living beings.
      """,
      source: "Khuddaka Nikāya, Sutta Nipāta 1.8"
    ),
    Quote(
      text: """
      You yourself must strive.
      The Buddhas only show the way.
      """,
      source: "Dhammapada, Verse 276"
    ),
    Quote(
      text: """
      The quieter you become,
      The more you are able to hear.
      """,
      source: "Meister Eckhart"
    ),
    Quote(
      text: """
      As a bee gathers nectar
      Without harming the flower,
      So should the wise move through the world.
      """,
      source: "Dhammapada, Verse 49"
    ),
    Quote(
      text: """
      You were born with wings.
      Why prefer to crawl through life?
      """,
      source: "Rumi"
    ),
    Quote(
      text: """
      What we plant in the soil of contemplation,
      We shall reap in the harvest of action.
      """,
      source: "Meister Eckhart"
    ),
    Quote(
      text: """
      The wound is the place
      Where the light enters you.
      """,
      source: "Rumi"
    ),
    Quote(
      text: """
      Stop acting so small.
      You are the universe in ecstatic motion.
      """,
      source: "Rumi"
    ),
    Quote(
      text: """
      Yesterday I was clever, so I wanted to change the world.
      Today I am wise, so I am changing myself.
      """,
      source: "Rumi"
    ),
    Quote(
      text: """
      Sitting quietly, doing nothing,
      spring comes, grass grows by itself.
      """,
      source: "Zen proverb"
    ),
    Quote(
      text: """
      To the mind that is still,
      the whole universe surrenders.
      """,
      source: "Lao Tzu"
    ),
    Quote(
      text: """
      Be melting snow.
      Wash yourself of yourself.
      """,
      source: "Jalāl al-Dīn Rūmī"
    ),
    Quote(
      text: """
      All know that the drop merges into the ocean,
      but few know that the ocean merges into the drop.
      """,
      source: "Kabir"
    ),
    Quote(
      text: """
      The soul becomes dyed 
      with the color of its thoughts.
      """,
      source: "Marcus Aurelius"
    ),
    Quote(
      text: """
      There are a thousand ways to kneel
      and kiss the ground.
      """,
      source: "Rumi"
    ),
    Quote(
      text: """
      Drop by drop is the water pot filled.
      Likewise, the wise man, gathering it little by little,
      fills himself with good.
      """,
      source: "Dhammapada, Verse 122"
    ),
  ]

  static func random(excluding quote: Quote? = nil) -> Quote {
    var available = all
    if let quote {
      available.removeAll { $0.text == quote.text }
    }
    return available.randomElement() ?? all[0]
  }
}
