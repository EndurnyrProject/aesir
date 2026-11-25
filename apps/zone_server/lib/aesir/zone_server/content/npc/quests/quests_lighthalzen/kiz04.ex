defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Kiz04 do
  @moduledoc """
  A cursed spirit reveals a memory of the city.

  ## Behavior

  - Shows a memory of new work and records the vision.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in03",
        x: 178,
        y: 22,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#kiz04",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch_", ctx), do: on_talk(ctx)

  @impl true
  def on_talk(ctx) do
    if count_item(ctx, 7345) > 0 do
      case get_char_var(ctx, :lhz_curse, 0) do
        0 -> ctx |> sc_start(:sc_curse, 1000, 0) |> soundeffect("tao_gunka_stand.wav", 0)
        curse when curse > 0 and curse < 26 -> witness_memory(ctx)
        _ -> ctx
      end
    else
      ctx
    end
  end

  defp witness_memory(ctx) do
    ctx =
      ctx
      |> mes("............")
      |> next()
      |> soundeffect("tao_gunka_stand.wav", 0)
      |> sc_start(:sc_blind, 60_000, 0)
      |> mes("............")
      |> next()
      |> mes("[?????]")
      |> mes("Hey, you won't")
      |> mes("believe it! Rekenber")
      |> mes("decided to hire us!")
      |> next()
      |> mes("[???????]")
      |> mes("You sure that's so great?")
      |> mes("Those big corporations")
      |> mes("always take advantage")
      |> mes("of the little guy. We're")
      |> mes("probably gonna end up")
      |> mes("slavin' away for our wages...")
      |> next()
      |> mes("[?????]")
      |> mes("No, that's not the")
      |> mes("case at all. I mean,")
      |> mes("sure, we won't start off")
      |> mes("with much responsibility,")
      |> mes("but they'll pay us well!")
      |> next()
      |> mes("[?????]")
      |> mes("Well, we do need to eat.")
      |> mes("If they're true to their word,")
      |> mes("that'll be even better!")
      |> next()
      |> mes("............")
      |> next()
      |> mes("............")
      |> next()
      |> mes("[???]")
      |> mes("Waaaah!")
      |> mes("Waaaaaaah~!")
      |> next()
      |> mes("[????]")
      |> mes("Woman, shut this")
      |> mes("baby up! Shut up, kid!")
      |> next()
      |> mes("[?????]")
      |> mes("Honey, please...")
      |> mes("He's just a baby!")
      |> next()
      |> mes("[????]")
      |> mes("I don't care how")
      |> mes("crummy this house is!")
      |> mes("It's mine and I want quiet!")
      |> next()
      |> mes("............")
      |> next()
      |> mes("............")
      |> next()

    ctx = emotion(ctx, :question, playerattached(ctx))

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I'm hearing things")
      |> mes("again! Where are all of")
      |> mes("these voices coming from?")
      |> close2()
      |> soundeffect("tao_gunka_stand.wav", 0)
      |> sc_end(:sc_blind)
      |> sc_start(:sc_curse, 5000, 0)

    if not Rathena.truthy?(get_char_var(ctx, :lhz_spi02, 0)) do
      set_char_var(ctx, :lhz_spi02, 1)
    else
      ctx
    end
  end
end
