defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.StrangeDevice do
  @moduledoc """
  Offers a device that transports the player into the dungeon puzzle.

  ## Behavior

  - Offers a choice to activate the device or leave it alone.
  - Activating it closes the dialog before warping the player.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "nyd_dun02",
        x: 178,
        y: 255,
        dir: 0,
        sprite: 844,
        name: "Strange Device",
        scope: :shared,
        unique_name: "Strange Device#ep13_out",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("There's something strange here.")
      |> mes("Maybe that device can be controlled from here.")
      |> next()
      |> select(["Try to control.", "Don't try to control it."])

    case choice do
      1 ->
        ctx
        |> mes("You press the device buttons and it suddenly becomes dark.")
        |> close()
        |> warp("nyd_dun02", 139, 268)

      2 ->
        ctx |> mes("You decide to leave it alone.") |> close()

      _ ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    specialeffect(ctx, :level99_4)
  end
end
