defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Kiz03 do
  @moduledoc """
  A cursed spirit reveals a memory of the city.

  ## Behavior

  - Shows a memory of a family’s hunger and records the vision.

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
        map: "lighthalzen",
        x: 344,
        y: 278,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#kiz03",
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
        0 -> ctx |> soundeffect("tao_gunka_stand.wav", 0) |> sc_start(:sc_curse, 1000, 0)
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
      |> mes("Honey, I'm sorry,")
      |> mes("but I... We know how")
      |> mes("hungry you are, but we")
      |> mes("have nothing to feed you.")
      |> next()
      |> mes("[?????]")
      |> mes("*Sniff* I know, I know,")
      |> mes("but somehow, that tragic")
      |> mes("truth eats away at me just")
      |> mes("a little bit more everyday...")
      |> next()
      |> mes("[?????]")
      |> mes("D-damn it...!")
      |> mes("Why do we have")
      |> mes("to live like this?!")
      |> mes("It's like we're less")
      |> mes("than animals. I hate this!")
      |> next()
      |> mes("............")
      |> next()
      |> mes("............")
      |> next()

    ctx = emotion(ctx, :question, playerattached(ctx))

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Those voices weren't")
      |> mes("just in my head, were they?")
      |> mes("Hello...? Anybody there...?")
      |> close2()
      |> sc_end(:sc_blind)
      |> sc_start(:sc_curse, 5000, 0)

    if not Rathena.truthy?(get_char_var(ctx, :lhz_spi01, 0)) do
      set_char_var(ctx, :lhz_spi01, 1)
    else
      ctx
    end
  end
end
