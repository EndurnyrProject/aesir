defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Kiz06 do
  @moduledoc """
  A cursed spirit reveals a memory of the city.

  ## Behavior

  - Shows a memory of a job offer and records the vision.

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
        x: 364,
        y: 315,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#kiz06",
        trigger: {3, 3}
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
      |> soundeffect("tao_gunka_stand.wav", 0)
      |> sc_start(:sc_blind, 60_000, 0)
      |> mes("............")
      |> next()
      |> mes("[?????]")
      |> mes("Listen, I know you're")
      |> mes("the newest hire, but you've")
      |> mes("shown us a lot of potential.")
      |> mes("I think you'd be a perfect")
      |> mes("fit for this new position.")
      |> next()
      |> mes("[???????]")
      |> mes("Are you really serious?")
      |> next()
      |> mes("[?????]")
      |> mes("I'll tell it to you straight.")
      |> mes("This new position will require")
      |> mes("you to be away from home once")
      |> mes("in a while, but that comes with")
      |> mes("the new responsibilities.")
      |> next()
      |> mes("[?????]")
      |> mes("But you'll receive")
      |> mes("many new benefits that")
      |> mes("I'm sure your family would")
      |> mes("appreciate and you'll be")
      |> mes("generously compensated.")
      |> next()
      |> mes("[???????]")
      |> mes(".............")
      |> next()
      |> mes("[???????]")
      |> mes("...Alright, I'm in.")
      |> next()
      |> mes("............")
      |> next()
      |> mes("............")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("............")
      |> close2()
      |> soundeffect("tao_gunka_stand.wav", 0)
      |> sc_end(:sc_blind)
      |> sc_start(:sc_curse, 5000, 0)

    if not Rathena.truthy?(get_char_var(ctx, :lhz_spi04, 0)) do
      set_char_var(ctx, :lhz_spi04, 1)
    else
      ctx
    end
  end
end
