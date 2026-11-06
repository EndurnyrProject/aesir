defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Monk.Trap do
  @moduledoc """
  Catches Monk marathon runners who stray off course and sends them back to the start.

  ## Behavior

  - Announces the trapped runner on the test map and warps them to the marathon start.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Dino9021
    - Celest
    - L0ne_W0lf
    - Samuray22
    - Kisuka
    - Lupus
    - Yor
    - Zephiris
    - Vicious
    - Silent

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "monk_test",
        x: 82,
        y: 384,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "MonkTrap"
      },
      %{
        map: "monk_test",
        x: 83,
        y: 384,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "Trap#t_monk1_2"
      },
      %{
        map: "monk_test",
        x: 82,
        y: 385,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "Trap#t_monk1_3"
      },
      %{
        map: "monk_test",
        x: 83,
        y: 385,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "Trap#t_monk1_4"
      },
      %{
        map: "monk_test",
        x: 38,
        y: 388,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "Trap#t_monk2_1",
        trigger: {0, 1}
      },
      %{
        map: "monk_test",
        x: 39,
        y: 388,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "Trap#t_monk2_2",
        trigger: {0, 1}
      },
      %{
        map: "monk_test",
        x: 38,
        y: 386,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "Trap#t_monk2_3"
      },
      %{
        map: "monk_test",
        x: 39,
        y: 386,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "Trap#t_monk2_4"
      },
      %{
        map: "monk_test",
        x: 11,
        y: 158,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "Trap#t_monk3_1",
        trigger: {1, 0}
      },
      %{
        map: "monk_test",
        x: 11,
        y: 159,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "Trap#t_monk3_2",
        trigger: {1, 0}
      },
      %{
        map: "monk_test",
        x: 13,
        y: 159,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "Trap#t_monk3_3"
      },
      %{
        map: "monk_test",
        x: 13,
        y: 158,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "Trap#t_monk3_4"
      },
      %{
        map: "monk_test",
        x: 11,
        y: 30,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "Trap#t_monk4_1",
        trigger: {3, 0}
      },
      %{
        map: "monk_test",
        x: 11,
        y: 31,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "Trap#t_monk4_2",
        trigger: {3, 0}
      },
      %{
        map: "monk_test",
        x: 15,
        y: 30,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "Trap#t_monk4_3"
      },
      %{
        map: "monk_test",
        x: 15,
        y: 31,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "Trap#t_monk4_4"
      },
      %{
        map: "monk_test",
        x: 70,
        y: 12,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "Trap#t_monk5_1",
        trigger: {0, 1}
      },
      %{
        map: "monk_test",
        x: 71,
        y: 12,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "Trap#t_monk5_2",
        trigger: {0, 1}
      },
      %{
        map: "monk_test",
        x: 70,
        y: 10,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "Trap#t_monk5_3"
      },
      %{
        map: "monk_test",
        x: 71,
        y: 10,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "Trap#t_monk5_4"
      },
      %{
        map: "monk_test",
        x: 186,
        y: 11,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "Trap#t_monk6_1",
        trigger: {2, 3}
      },
      %{
        map: "monk_test",
        x: 189,
        y: 11,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "Trap#t_monk6_2",
        trigger: {0, 3}
      },
      %{
        map: "monk_test",
        x: 387,
        y: 43,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "Trap#t_monk7_1",
        trigger: {1, 0}
      },
      %{
        map: "monk_test",
        x: 387,
        y: 42,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "Trap#t_monk7_2",
        trigger: {1, 0}
      },
      %{
        map: "monk_test",
        x: 389,
        y: 43,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "Trap#t_monk7_3"
      },
      %{
        map: "monk_test",
        x: 389,
        y: 42,
        dir: 0,
        sprite: -1,
        name: "Trap",
        scope: :shared,
        unique_name: "Trap#t_monk7_4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    ctx
    |> mapannounce("monk_test", "#{char_name(ctx, 0)}, you're trapped. You will be returned.", 1)
    |> warp("monk_test", 387, 387)
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  # rAthena starts a click at the first label, so it runs this body too.
  def on_talk(ctx), do: on_event("OnTouch_", ctx)
end
