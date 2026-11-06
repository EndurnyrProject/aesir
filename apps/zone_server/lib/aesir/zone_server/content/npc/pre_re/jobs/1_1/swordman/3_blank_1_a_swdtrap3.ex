defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.M11.Swordman.M3Blank1ASwdtrap3 do
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
        x: 17,
        y: 174,
        dir: 0,
        sprite: -1,
        name: "3_blank_1_a::SwdTrap3",
        scope: :pre_renewal,
        unique_name: "SwdTrap3",
        trigger: {2, 0}
      },
      %{
        map: "job_sword1",
        x: 17,
        y: 163,
        dir: 0,
        sprite: -1,
        name: "3_blank_2_a",
        scope: :pre_renewal,
        trigger: {2, 0}
      },
      %{
        map: "job_sword1",
        x: 29,
        y: 171,
        dir: 0,
        sprite: -1,
        name: "3_blank_3_a",
        scope: :pre_renewal,
        trigger: {2, 0}
      },
      %{
        map: "job_sword1",
        x: 31,
        y: 168,
        dir: 0,
        sprite: -1,
        name: "3_blank_3_b",
        scope: :pre_renewal,
        trigger: {0, 2}
      },
      %{
        map: "job_sword1",
        x: 28,
        y: 166,
        dir: 0,
        sprite: -1,
        name: "3_blank_3_c",
        scope: :pre_renewal,
        trigger: {2, 0}
      },
      %{
        map: "job_sword1",
        x: 26,
        y: 168,
        dir: 0,
        sprite: -1,
        name: "3_blank_3_d",
        scope: :pre_renewal,
        trigger: {0, 2}
      },
      %{
        map: "job_sword1",
        x: 36,
        y: 169,
        dir: 0,
        sprite: -1,
        name: "3_blank_4_a",
        scope: :pre_renewal,
        trigger: {0, 0}
      },
      %{
        map: "job_sword1",
        x: 37,
        y: 169,
        dir: 0,
        sprite: -1,
        name: "3_blank_4_b",
        scope: :pre_renewal,
        trigger: {0, 0}
      },
      %{
        map: "job_sword1",
        x: 37,
        y: 168,
        dir: 0,
        sprite: -1,
        name: "3_blank_4_c",
        scope: :pre_renewal,
        trigger: {0, 0}
      },
      %{
        map: "job_sword1",
        x: 36,
        y: 168,
        dir: 0,
        sprite: -1,
        name: "3_blank_4_c2",
        scope: :pre_renewal,
        trigger: {0, 0}
      },
      %{
        map: "job_sword1",
        x: 40,
        y: 175,
        dir: 0,
        sprite: -1,
        name: "3_blank_5_a",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 41,
        y: 175,
        dir: 0,
        sprite: -1,
        name: "3_blank_5_b",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 41,
        y: 171,
        dir: 0,
        sprite: -1,
        name: "3_blank_6_a",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 41,
        y: 170,
        dir: 0,
        sprite: -1,
        name: "3_blank_6_b",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 41,
        y: 167,
        dir: 0,
        sprite: -1,
        name: "3_blank_6_c",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 41,
        y: 166,
        dir: 0,
        sprite: -1,
        name: "3_blank_6_d",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 42,
        y: 169,
        dir: 0,
        sprite: -1,
        name: "3_blank_6_e",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 43,
        y: 170,
        dir: 0,
        sprite: -1,
        name: "3_blank_6_f",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 43,
        y: 167,
        dir: 0,
        sprite: -1,
        name: "3_blank_6_g",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 40,
        y: 162,
        dir: 0,
        sprite: -1,
        name: "3_blank_7_a",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 41,
        y: 162,
        dir: 0,
        sprite: -1,
        name: "3_blank_7_b",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 46,
        y: 175,
        dir: 0,
        sprite: -1,
        name: "3_blank_8_a",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 51,
        y: 175,
        dir: 0,
        sprite: -1,
        name: "3_blank_8_b",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 47,
        y: 174,
        dir: 0,
        sprite: -1,
        name: "3_blank_8_c",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 50,
        y: 174,
        dir: 0,
        sprite: -1,
        name: "3_blank_8_d",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 48,
        y: 173,
        dir: 0,
        sprite: -1,
        name: "3_blank_8_e",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 49,
        y: 173,
        dir: 0,
        sprite: -1,
        name: "3_blank_8_f",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 46,
        y: 162,
        dir: 0,
        sprite: -1,
        name: "3_blank_9_a",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 51,
        y: 162,
        dir: 0,
        sprite: -1,
        name: "3_blank_9_b",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 47,
        y: 163,
        dir: 0,
        sprite: -1,
        name: "3_blank_9_c",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 50,
        y: 163,
        dir: 0,
        sprite: -1,
        name: "3_blank_9_d",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 48,
        y: 164,
        dir: 0,
        sprite: -1,
        name: "3_blank_9_e",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 49,
        y: 164,
        dir: 0,
        sprite: -1,
        name: "3_blank_9_f",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 54,
        y: 170,
        dir: 0,
        sprite: -1,
        name: "3_blank_10_a",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 55,
        y: 170,
        dir: 0,
        sprite: -1,
        name: "3_blank_10_b",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 54,
        y: 167,
        dir: 0,
        sprite: -1,
        name: "3_blank_10_c",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 55,
        y: 167,
        dir: 0,
        sprite: -1,
        name: "3_blank_10_d",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 53,
        y: 169,
        dir: 0,
        sprite: -1,
        name: "3_blank_10_e",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 53,
        y: 168,
        dir: 0,
        sprite: -1,
        name: "3_blank_10_f",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 56,
        y: 169,
        dir: 0,
        sprite: -1,
        name: "3_blank_10_g",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 56,
        y: 168,
        dir: 0,
        sprite: -1,
        name: "3_blank_10_h",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 58,
        y: 175,
        dir: 0,
        sprite: -1,
        name: "3_blank_11_a",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 59,
        y: 174,
        dir: 0,
        sprite: -1,
        name: "3_blank_11_b",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 60,
        y: 173,
        dir: 0,
        sprite: -1,
        name: "3_blank_11_c",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 61,
        y: 172,
        dir: 0,
        sprite: -1,
        name: "3_blank_11_d",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 58,
        y: 162,
        dir: 0,
        sprite: -1,
        name: "3_blank_12_a",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 59,
        y: 163,
        dir: 0,
        sprite: -1,
        name: "3_blank_12_b",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 60,
        y: 164,
        dir: 0,
        sprite: -1,
        name: "3_blank_12_c",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 61,
        y: 165,
        dir: 0,
        sprite: -1,
        name: "3_blank_12_d",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 76,
        y: 172,
        dir: 0,
        sprite: -1,
        name: "3_blank_13_a",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 77,
        y: 173,
        dir: 0,
        sprite: -1,
        name: "3_blank_13_b",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 78,
        y: 174,
        dir: 0,
        sprite: -1,
        name: "3_blank_13_c",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 79,
        y: 175,
        dir: 0,
        sprite: -1,
        name: "3_blank_13_d",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 76,
        y: 165,
        dir: 0,
        sprite: -1,
        name: "3_blank_14_a",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 77,
        y: 164,
        dir: 0,
        sprite: -1,
        name: "3_blank_14_b",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 78,
        y: 163,
        dir: 0,
        sprite: -1,
        name: "3_blank_14_c",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 79,
        y: 162,
        dir: 0,
        sprite: -1,
        name: "3_blank_14_d",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 94,
        y: 175,
        dir: 0,
        sprite: -1,
        name: "3_blank_15_a",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 95,
        y: 174,
        dir: 0,
        sprite: -1,
        name: "3_blank_15_b",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 98,
        y: 174,
        dir: 0,
        sprite: -1,
        name: "3_blank_15_c",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 99,
        y: 175,
        dir: 0,
        sprite: -1,
        name: "3_blank_16_d",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 96,
        y: 169,
        dir: 0,
        sprite: -1,
        name: "3_blank_17_a",
        scope: :pre_renewal,
        trigger: {0, 0}
      },
      %{
        map: "job_sword1",
        x: 97,
        y: 169,
        dir: 0,
        sprite: -1,
        name: "3_blank_17_b",
        scope: :pre_renewal,
        trigger: {0, 0}
      },
      %{
        map: "job_sword1",
        x: 97,
        y: 168,
        dir: 0,
        sprite: -1,
        name: "3_blank_17_c",
        scope: :pre_renewal,
        trigger: {0, 0}
      },
      %{
        map: "job_sword1",
        x: 96,
        y: 168,
        dir: 0,
        sprite: -1,
        name: "3_blank_17_d",
        scope: :pre_renewal,
        trigger: {0, 0}
      },
      %{
        map: "job_sword1",
        x: 94,
        y: 162,
        dir: 0,
        sprite: -1,
        name: "3_blank_18_a",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 95,
        y: 163,
        dir: 0,
        sprite: -1,
        name: "3_blank_18_b",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 98,
        y: 163,
        dir: 0,
        sprite: -1,
        name: "3_blank_18_c",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 99,
        y: 162,
        dir: 0,
        sprite: -1,
        name: "3_blank_18_d",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 114,
        y: 175,
        dir: 0,
        sprite: -1,
        name: "3_blank_19_a",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 115,
        y: 175,
        dir: 0,
        sprite: -1,
        name: "3_blank_19_b",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 114,
        y: 162,
        dir: 0,
        sprite: -1,
        name: "3_blank_20_a",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 115,
        y: 162,
        dir: 0,
        sprite: -1,
        name: "3_blank_20_b",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 126,
        y: 175,
        dir: 0,
        sprite: -1,
        name: "3_blank_21_a",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 127,
        y: 175,
        dir: 0,
        sprite: -1,
        name: "3_blank_21_b",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 126,
        y: 162,
        dir: 0,
        sprite: -1,
        name: "3_blank_23_a",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 127,
        y: 162,
        dir: 0,
        sprite: -1,
        name: "3_blank_23_b",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 160,
        y: 174,
        dir: 0,
        sprite: -1,
        name: "3_blank_24_a",
        scope: :pre_renewal,
        trigger: {0, 2}
      },
      %{
        map: "job_sword1",
        x: 161,
        y: 174,
        dir: 0,
        sprite: -1,
        name: "3_blank_24_b",
        scope: :pre_renewal,
        trigger: {0, 2}
      },
      %{
        map: "job_sword1",
        x: 160,
        y: 163,
        dir: 0,
        sprite: -1,
        name: "3_blank_25_a",
        scope: :pre_renewal,
        trigger: {0, 2}
      },
      %{
        map: "job_sword1",
        x: 161,
        y: 163,
        dir: 0,
        sprite: -1,
        name: "3_blank_25_b",
        scope: :pre_renewal,
        trigger: {0, 2}
      },
      %{
        map: "job_sword1",
        x: 168,
        y: 175,
        dir: 0,
        sprite: -1,
        name: "3_blank_26_a",
        scope: :pre_renewal,
        trigger: {0, 2}
      },
      %{
        map: "job_sword1",
        x: 169,
        y: 175,
        dir: 0,
        sprite: -1,
        name: "3_blank_26_b",
        scope: :pre_renewal,
        trigger: {0, 2}
      },
      %{
        map: "job_sword1",
        x: 168,
        y: 162,
        dir: 0,
        sprite: -1,
        name: "3_blank_27_a",
        scope: :pre_renewal,
        trigger: {0, 2}
      },
      %{
        map: "job_sword1",
        x: 169,
        y: 162,
        dir: 0,
        sprite: -1,
        name: "3_blank_27_b",
        scope: :pre_renewal,
        trigger: {0, 2}
      },
      %{
        map: "job_sword1",
        x: 176,
        y: 174,
        dir: 0,
        sprite: -1,
        name: "3_blank_28_a",
        scope: :pre_renewal,
        trigger: {0, 2}
      },
      %{
        map: "job_sword1",
        x: 177,
        y: 174,
        dir: 0,
        sprite: -1,
        name: "3_blank_28_b",
        scope: :pre_renewal,
        trigger: {0, 2}
      },
      %{
        map: "job_sword1",
        x: 178,
        y: 173,
        dir: 0,
        sprite: -1,
        name: "3_blank_28_c",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 178,
        y: 172,
        dir: 0,
        sprite: -1,
        name: "3_blank_28_d",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 181,
        y: 174,
        dir: 0,
        sprite: -1,
        name: "3_blank_28_e",
        scope: :pre_renewal,
        trigger: {2, 0}
      },
      %{
        map: "job_sword1",
        x: 179,
        y: 169,
        dir: 0,
        sprite: -1,
        name: "3_blank_29_a",
        scope: :pre_renewal,
        trigger: {3, 0}
      },
      %{
        map: "job_sword1",
        x: 179,
        y: 168,
        dir: 0,
        sprite: -1,
        name: "3_blank_29_b",
        scope: :pre_renewal,
        trigger: {3, 0}
      },
      %{
        map: "job_sword1",
        x: 182,
        y: 169,
        dir: 0,
        sprite: -1,
        name: "3_blank_29_c",
        scope: :pre_renewal,
        trigger: {0, 2}
      },
      %{
        map: "job_sword1",
        x: 183,
        y: 169,
        dir: 0,
        sprite: -1,
        name: "3_blank_29_d",
        scope: :pre_renewal,
        trigger: {0, 2}
      },
      %{
        map: "job_sword1",
        x: 181,
        y: 167,
        dir: 0,
        sprite: -1,
        name: "3_blank_29_e",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 181,
        y: 166,
        dir: 0,
        sprite: -1,
        name: "3_blank_29_f",
        scope: :pre_renewal,
        trigger: {1, 0}
      },
      %{
        map: "job_sword1",
        x: 183,
        y: 167,
        dir: 0,
        sprite: -1,
        name: "3_blank_29_g",
        scope: :pre_renewal,
        trigger: {0, 1}
      },
      %{
        map: "job_sword1",
        x: 176,
        y: 163,
        dir: 0,
        sprite: -1,
        name: "3_blank_30_a",
        scope: :pre_renewal,
        trigger: {0, 2}
      },
      %{
        map: "job_sword1",
        x: 177,
        y: 163,
        dir: 0,
        sprite: -1,
        name: "3_blank_30_b",
        scope: :pre_renewal,
        trigger: {0, 2}
      },
      %{
        map: "job_sword1",
        x: 181,
        y: 163,
        dir: 0,
        sprite: -1,
        name: "3_blank_30_c",
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
        warp(ctx, "job_sword1", 195, 15)

      2 ->
        warp(ctx, "job_sword1", 195, 38)

      3 ->
        warp(ctx, "job_sword1", 231, 30)

      4 ->
        warp(ctx, "job_sword1", 198, 65)

      5 ->
        warp(ctx, "job_sword1", 196, 116)

      _ ->
        ctx
    end
  end
end
