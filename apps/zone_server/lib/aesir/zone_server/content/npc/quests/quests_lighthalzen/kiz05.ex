defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Kiz05 do
  @moduledoc """
  A cursed spirit reveals a memory of the city.

  ## Behavior

  - Shows a memory of poverty and records the vision.

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
        x: 295,
        y: 227,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#kiz05",
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
        0 -> sc_start(ctx, :sc_curse, 1000, 0)
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
      |> soundeffect("loli_ruri_stand.wav", 0)
      |> sc_start(:sc_blind, 60_000, 0)
      |> mes("............")
      |> next()
      |> mes("[?????]")
      |> mes("Mommy, why don't those")
      |> mes("dirty people get new clothes?")
      |> mes("Don't they know it's gross?")
      |> mes("They're scaring me...")
      |> next()
      |> mes("[???????]")
      |> mes("Honey, don't look at")
      |> mes("them and hurry up!")
      |> next()
      |> mes("[????]")
      |> mes("Please, do you have")
      |> mes("any spare change? I...")
      |> mes("I need something to eat...")
      |> next()
      |> mes("............")
      |> next()
      |> mes("............")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("This is...")
      |> mes("This is insane!")
      |> mes("I must be hallucinating!")
      |> close2()
      |> soundeffect("loli_ruri_stand.wav", 0)
      |> sc_end(:sc_blind)
      |> sc_start(:sc_curse, 3000, 0)

    if not Rathena.truthy?(get_char_var(ctx, :lhz_spi03, 0)) do
      set_char_var(ctx, :lhz_spi03, 1)
    else
      ctx
    end
  end
end
