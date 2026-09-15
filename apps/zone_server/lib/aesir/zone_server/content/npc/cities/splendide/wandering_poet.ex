defmodule Aesir.ZoneServer.Content.Npc.Cities.Splendide.WanderingPoet do
  @moduledoc """
  Introduces Poet Nell and performs a selected piece of music.

  ## Behavior

  - Explains how Nell came to Splendide and connected with the Laphine through music.
  - Plays one of four selected songs, including the full tale of the Ring of Nibelungen.
  - Responds defensively when the player declines to listen.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "spl_in01",
        x: 172,
        y: 225,
        dir: 3,
        sprite: 51,
        name: "Wandering Poet",
        scope: :shared,
        unique_name: "Wandering Poet#ep13"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, _choice} =
      ctx
      |> cutin("god_nelluad02", 2)
      |> mes("[Poet Nell]")
      |> mes("Hi~~ do you hear the beautiful music coming from afar~?")
      |> next()
      |> select(["Who are you?"])

    {ctx, choice} = introduce_nell(ctx)

    ctx =
      case choice do
        1 -> offer_song(ctx)
        2 -> respond_to_refusal(ctx)
        _ -> ctx
      end

    ctx |> close() |> cutin("god_nelluad01", 255)
  end

  defp introduce_nell(ctx) do
    ctx
    |> cutin("god_nelluad01", 2)
    |> mes("[Poet Nell]")
    |> mes("Who, me...?")
    |> mes("I am just a poet enjoying the ambience...")
    |> next()
    |> mes("[Poet Nell]")
    |> mes(
      "I cam here the other day, requesting to take notes of this new world and they allow me to follow the adventurers here."
    )
    |> next()
    |> mes("[Poet Nell]")
    |> mes("I became familiar with the Lapine.")
    |> mes("It was quite awkward at first... Since I didn't knew their language.")
    |> mes("But, one I started to play my instruments... they loved it.")
    |> next()
    |> mes("[Poet Nell]")
    |> mes("They're fairies that know how to enjoy their lives..")
    |> mes("How happy they are...")
    |> mes("They are quite curious... I am honored to have met them...")
    |> next()
    |> mes("[Poet Nell]")
    |> mes("So do you want to listen to my playing?")
    |> next()
    |> select(["Sure.", "Not really."])
  end

  defp offer_song(ctx) do
    {ctx, song} =
      ctx
      |> mes("[Poet Nell]")
      |> mes("What song do you want??")
      |> next()
      |> select([
        "Poet of Bragie",
        "Chaos in Eternity",
        "Sunset Assassin",
        "Ring of Nibelungen"
      ])

    case song do
      1 -> play_poet_of_bragie(ctx)
      2 -> play_chaos_in_eternity(ctx)
      3 -> play_sunset_assassin(ctx)
      4 -> play_ring_of_nibelungen(ctx)
      _ -> ctx
    end
  end

  defp play_poet_of_bragie(ctx) do
    ctx
    |> cutin("god_nelluad02", 2)
    |> mes("[Poet Nell]")
    |> mes("Poet of Bragie!")
    |> mes("You must have a keen ear.")
    |> soundeffect("bragis_poem.wav", 0)
  end

  defp play_chaos_in_eternity(ctx) do
    ctx
    |> cutin("god_nelluad02", 2)
    |> mes("[Poet Nell]")
    |> mes("Chaos in Eternity...")
    |> mes("This is a great piece but I wouldn't recommend it while dining...")
    |> soundeffect("chaos_of_eternity.wav", 0)
  end

  defp play_sunset_assassin(ctx) do
    ctx
    |> cutin("god_nelluad02", 2)
    |> mes("[Poet Nell]")
    |> mes("Sunset Assassin!")
    |> mes("Do you like Assassins?")
    |> mes("This song tells of a legendary Assassin Cross that lived in the desert.")
    |> soundeffect("assassin_of_sunset.wav", 0)
  end

  defp play_ring_of_nibelungen(ctx) do
    ctx
    |> cutin("god_nelluad02", 2)
    |> mes("[Poet Nell]")
    |> mes("Ring of Nibelungen...")
    |> mes("This song has quite an interesting story~")
    |> next()
    |> soundeffect("ring_of_nibelungen.wav", 0)
    |> mes("^4d4dff There was a river named Rhein that")
    |> mes("that would shine as if made of gold.")
    |> mes("It's secret hidden from all since")
    |> mes("before this story was told...^000000")
    |> next()
    |> mes("^4d4dff Valhalla was born from the goddess Freya.")
    |> mes("The envious Rocky destroyed the goddess of beauty.^000000")
    |> mes("^4d4dff Out of it's depths was born a ring made of fire.")
    |> mes("A ring so strong it held the god's desires~^000000")
    |> next()
    |> mes("^4d4dff Alberich's treasure now holds that power.")
    |> mes("The power of the ring that held all the god's desires.^000000")
    |> next()
    |> mes("^4d4dff The treasure was used to buy the world's soul.")
    |> mes("A soul purchased with the weight of gold.^000000")
    |> next()
    |> mes(
      "^4d4dff Rocky afraid of losing control. transforms poor Alberich to the shape of a toad."
    )
    |> next()
    |> mes(
      "^4d4dff Alberich swears with the last of his breath, that his treasured ring will curse it's wearer till death."
    )
    |> next()
    |> mes("^4d4dff Forever will the bearer be, cursed with Rocky's jealousy.")
  end

  defp respond_to_refusal(ctx) do
    {ctx, _choice} =
      ctx
      |> cutin("god_nelluad03", 2)
      |> mes("[Poet Nell]")
      |> mes("Why not?")
      |> mes("Why would you stare at me like that if you didn't want to listen to my playing")
      |> next()
      |> select(["You look like someone I know."])

    ctx
    |> cutin("god_nelluad04", 2)
    |> mes("[Poet Nell]")
    |> mes("Eh?")
    |> mes("No way!")
    |> mes("Maybe you're confused..!")
    |> next()
    |> mes("[Poet Nell]")
    |> mes("Yes, I look quite common...")
    |> mes("But I doubt we've ever met before.")
    |> next()
    |> cutin("god_nelluad01", 255)
    |> mes("- Nell seems embarrassed, then starts playing very complicated music -")
  end
end
