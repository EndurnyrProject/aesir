defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M11.Swordman.M2Blank1ASwdtrap2 do
  @moduledoc """
  Warps swordman test applicants who fall into a course pitfall.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script pre-re/jobs/1-1/swordman.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "job_sword1",
        x: 56,
        y: 212,
        dir: 0,
        sprite: -1,
        name: "2_blank_1_a::SwdTrap2",
        scope: :pre_renewal,
        unique_name: "SwdTrap2",
        trigger: {40, 0}
      },
      %{
        map: "job_sword1",
        x: 95,
        y: 212,
        dir: 0,
        sprite: -1,
        name: "2_blank_1_b",
        scope: :pre_renewal,
        trigger: {2, 0}
      },
      %{
        map: "job_sword1",
        x: 56,
        y: 210,
        dir: 0,
        sprite: -1,
        name: "2_blank_2_a",
        scope: :pre_renewal,
        trigger: {40, 0}
      },
      %{
        map: "job_sword1",
        x: 95,
        y: 210,
        dir: 0,
        sprite: -1,
        name: "2_blank_2_b",
        scope: :pre_renewal,
        trigger: {2, 0}
      },
      %{
        map: "job_sword1",
        x: 16,
        y: 206,
        dir: 0,
        sprite: -1,
        name: "2_blank_2_c",
        scope: :pre_renewal,
        trigger: {0, 3}
      },
      %{
        map: "job_sword1",
        x: 97,
        y: 206,
        dir: 0,
        sprite: -1,
        name: "2_blank_2_d",
        scope: :pre_renewal,
        trigger: {0, 3}
      },
      %{
        map: "job_sword1",
        x: 56,
        y: 203,
        dir: 0,
        sprite: -1,
        name: "2_blank_2_e",
        scope: :pre_renewal,
        trigger: {40, 0}
      },
      %{
        map: "job_sword1",
        x: 95,
        y: 203,
        dir: 0,
        sprite: -1,
        name: "2_blank_2_f",
        scope: :pre_renewal,
        trigger: {2, 0}
      },
      %{
        map: "job_sword1",
        x: 56,
        y: 201,
        dir: 0,
        sprite: -1,
        name: "2_blank_3_a",
        scope: :pre_renewal,
        trigger: {40, 0}
      },
      %{
        map: "job_sword1",
        x: 95,
        y: 201,
        dir: 0,
        sprite: -1,
        name: "2_blank_3_b",
        scope: :pre_renewal,
        trigger: {2, 0}
      },
      %{
        map: "job_sword1",
        x: 113,
        y: 212,
        dir: 0,
        sprite: -1,
        name: "2_blank_4_a",
        scope: :pre_renewal,
        trigger: {14, 0}
      },
      %{
        map: "job_sword1",
        x: 125,
        y: 212,
        dir: 0,
        sprite: -1,
        name: "2_blank_4_b",
        scope: :pre_renewal,
        trigger: {2, 0}
      },
      %{
        map: "job_sword1",
        x: 113,
        y: 210,
        dir: 0,
        sprite: -1,
        name: "2_blank_5_a",
        scope: :pre_renewal,
        trigger: {14, 0}
      },
      %{
        map: "job_sword1",
        x: 125,
        y: 210,
        dir: 0,
        sprite: -1,
        name: "2_blank_5_b",
        scope: :pre_renewal,
        trigger: {2, 0}
      },
      %{
        map: "job_sword1",
        x: 100,
        y: 206,
        dir: 0,
        sprite: -1,
        name: "2_blank_5_c",
        scope: :pre_renewal,
        trigger: {0, 3}
      },
      %{
        map: "job_sword1",
        x: 127,
        y: 206,
        dir: 0,
        sprite: -1,
        name: "2_blank_5_d",
        scope: :pre_renewal,
        trigger: {0, 3}
      },
      %{
        map: "job_sword1",
        x: 113,
        y: 203,
        dir: 0,
        sprite: -1,
        name: "2_blank_5_e",
        scope: :pre_renewal,
        trigger: {14, 0}
      },
      %{
        map: "job_sword1",
        x: 125,
        y: 210,
        dir: 0,
        sprite: -1,
        name: "2_blank_5_f",
        scope: :pre_renewal,
        trigger: {2, 0}
      },
      %{
        map: "job_sword1",
        x: 113,
        y: 201,
        dir: 0,
        sprite: -1,
        name: "2_blank_6_a",
        scope: :pre_renewal,
        trigger: {14, 0}
      },
      %{
        map: "job_sword1",
        x: 113,
        y: 201,
        dir: 0,
        sprite: -1,
        name: "2_blank_6_b",
        scope: :pre_renewal,
        trigger: {2, 0}
      },
      %{
        map: "job_sword1",
        x: 155,
        y: 212,
        dir: 0,
        sprite: -1,
        name: "2_blank_7_a",
        scope: :pre_renewal,
        trigger: {21, 0}
      },
      %{
        map: "job_sword1",
        x: 181,
        y: 212,
        dir: 0,
        sprite: -1,
        name: "2_blank_7_b",
        scope: :pre_renewal,
        trigger: {2, 0}
      },
      %{
        map: "job_sword1",
        x: 155,
        y: 210,
        dir: 0,
        sprite: -1,
        name: "2_blank_8_a",
        scope: :pre_renewal,
        trigger: {21, 0}
      },
      %{
        map: "job_sword1",
        x: 181,
        y: 210,
        dir: 0,
        sprite: -1,
        name: "2_blank_8_b",
        scope: :pre_renewal,
        trigger: {2, 0}
      },
      %{
        map: "job_sword1",
        x: 130,
        y: 206,
        dir: 0,
        sprite: -1,
        name: "2_blank_8_c",
        scope: :pre_renewal,
        trigger: {0, 3}
      },
      %{
        map: "job_sword1",
        x: 183,
        y: 206,
        dir: 0,
        sprite: -1,
        name: "2_blank_8_d",
        scope: :pre_renewal,
        trigger: {0, 3}
      },
      %{
        map: "job_sword1",
        x: 155,
        y: 203,
        dir: 0,
        sprite: -1,
        name: "2_blank_8_e",
        scope: :pre_renewal,
        trigger: {21, 0}
      },
      %{
        map: "job_sword1",
        x: 181,
        y: 203,
        dir: 0,
        sprite: -1,
        name: "2_blank_8_f",
        scope: :pre_renewal,
        trigger: {2, 0}
      },
      %{
        map: "job_sword1",
        x: 155,
        y: 201,
        dir: 0,
        sprite: -1,
        name: "2_blank_9_a",
        scope: :pre_renewal,
        trigger: {40, 0}
      },
      %{
        map: "job_sword1",
        x: 181,
        y: 201,
        dir: 0,
        sprite: -1,
        name: "2_blank_9_b",
        scope: :pre_renewal,
        trigger: {2, 0}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @spec ev_ontouch(Ctx.t()) :: Ctx.t()
  def ev_ontouch(ctx) do
    case Enum.random(1..5) do
      1 ->
        warp(ctx, "job_sword1", 162, 120)

      2 ->
        warp(ctx, "job_sword1", 94, 120)

      3 ->
        warp(ctx, "job_sword1", 94, 85)

      4 ->
        warp(ctx, "job_sword1", 162, 85)

      5 ->
        warp(ctx, "job_sword1", 130, 47)

      _ ->
        ctx
    end
  end
end
