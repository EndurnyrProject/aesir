defmodule Aesir.ZoneServer.Content.Npc.Functions.FClearjobvar do
  @moduledoc """
  Resets every job-change quest variable.

  ## Behavior

  Called when a character takes a new class: all first, second, expanded and Super Novice quest
  progress, plus the remaining support variables, start over at zero.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script other/Global_Functions.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx

  @variables ~w(
    JBLVL FIRSTAID PLAYDEAD got_bandage got_novnametag
    job_acolyte_q job_acolyte_q2 job_archer_q job_magician_q
    job_merchant_q job_merchant_q2 job_merchant_q3 job_sword_q SWTEST job_thief_q
    SUPNOV_Q
    ASSIN_Q ASSIN_Q2 ASSIN_Q3 BSMITH_Q BSMITH_Q2 HNTR_Q HNTR_Q2 KNIGHT_Q KNIGHT_Q2
    PRIEST_Q PRIEST_Q2 PRIEST_Q3 WIZ_Q WIZ_Q2
    ROGUE_Q ROGUE_Q2 ALCH_Q ALCH_Q2 CRUS_Q MONK_Q JOB_MONK_C SAGE_Q SAGE_Q2 DANC_Q BARD_Q
    TAEK_Q TK_Q STGL_Q SOUL_Q GUNS_Q NINJ_Q
  )a

  @doc "Callable rAthena global function `F_ClearJobVar`; zeroes the quest variables."
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), nil}
  def call(ctx, _args), do: {Enum.reduce(@variables, ctx, &set_char_var(&2, &1, 0)), nil}
end
