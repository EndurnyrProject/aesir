defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.LiDoor do
  @moduledoc """
  Controls access to a home during the epidemic.

  ## Behavior

  - Advances the curse quest when the door is locked.

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
        x: 324,
        y: 322,
        dir: 0,
        sprite: 45,
        name: "",
        scope: :shared,
        unique_name: "#li_door",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: visit_door(ctx)

  @impl true
  def on_talk(ctx), do: visit_door(ctx)

  defp visit_door(ctx) do
    progress = get_char_var(ctx, :lhz_curse, 0)

    cond do
      progress > 19 and progress < 23 ->
        ctx
        |> mes("^3355FFThe door is locked.^000000")
        |> set_char_var(:lhz_curse, progress + 1)
        |> close()

      progress > 23 ->
        ctx
        |> mes("^3355FFThe door is locked.^000000")
        |> next()
        |> mes("[Citizen]")
        |> mes("I'm sorry, but another")
        |> mes("epidemic is starting to")
        |> mes("spread around the slums.")
        |> mes("We're not going outside and we're keeping our children safe!")
        |> next()
        |> mes("[Citizen]")
        |> mes("Not to be unfriendly,")
        |> mes("but you should be careful")
        |> mes("too. The living conditions")
        |> mes("of this area aren't exactly")
        |> mes("sanitary, you know?")
        |> close()

      true ->
        warp(ctx, "lhz_in03", 15, 162)
    end
  end
end
