defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.RogueSkills.Kienna do
  @moduledoc """
  Kienna, the training partner who drills Rogues in blocking movement for Close Confine.

  ## Behavior

  - Appears at one of eight spots in the training arena; touching her runs the `F_Kienna`
    training exercise with the touched placement's suffix.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - 2Spiritual Kid
    - DracoRPG
    - L0ne_W0lf
    - Samuray22
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_are01",
        x: 149,
        y: 162,
        dir: 0,
        sprite: 700,
        name: "Kienna",
        scope: :shared,
        unique_name: "Kienna#1st",
        trigger: {1, 1}
      },
      %{
        map: "prt_are01",
        x: 136,
        y: 150,
        dir: 0,
        sprite: 700,
        name: "Kienna",
        scope: :shared,
        unique_name: "Kienna#2nd",
        trigger: {1, 1}
      },
      %{
        map: "prt_are01",
        x: 150,
        y: 138,
        dir: 0,
        sprite: 700,
        name: "Kienna",
        scope: :shared,
        unique_name: "Kienna#3rd",
        trigger: {1, 1}
      },
      %{
        map: "prt_are01",
        x: 163,
        y: 147,
        dir: 0,
        sprite: 700,
        name: "Kienna",
        scope: :shared,
        unique_name: "Kienna#4th",
        trigger: {1, 1}
      },
      %{
        map: "prt_are01",
        x: 134,
        y: 140,
        dir: 0,
        sprite: 700,
        name: "Kienna",
        scope: :shared,
        unique_name: "Kienna#5th",
        trigger: {1, 1}
      },
      %{
        map: "prt_are01",
        x: 161,
        y: 140,
        dir: 0,
        sprite: 700,
        name: "Kienna",
        scope: :shared,
        unique_name: "Kienna#6th",
        trigger: {1, 1}
      },
      %{
        map: "prt_are01",
        x: 161,
        y: 160,
        dir: 0,
        sprite: 700,
        name: "Kienna",
        scope: :shared,
        unique_name: "Kienna#7th",
        trigger: {1, 1}
      },
      %{
        map: "prt_are01",
        x: 138,
        y: 159,
        dir: 0,
        sprite: 700,
        name: "Kienna",
        scope: :shared,
        unique_name: "Kienna#8th",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FKienna
  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    {ctx, _} = FKienna.call(ctx, [strnpcinfo(ctx, 2)])
    ctx
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
