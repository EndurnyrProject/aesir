defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.RosimmirEntrance do
  @moduledoc """
  The Rosimier Mansion entrance admits adventurers carrying its key.

  ## Behavior

  - Checks for the mansion key on touch and transfers its bearer inside.
  - Describes the locked entrance when the key is missing.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno",
        x: 273,
        y: 141,
        dir: 0,
        sprite: 45,
        name: "Rosimmir_Entrance",
        scope: :shared,
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    if count_item(ctx, 7498) < 1 do
      ctx
      |> mes("That mansion seems to have")
      |> mes("been destroyed by the time.")
      |> mes("However, the door looks like")
      |> mes("it'd be still operational if")
      |> mes("you had the right key.")
      |> close()
    else
      warp(ctx, "kh_rossi", 20, 92)
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
