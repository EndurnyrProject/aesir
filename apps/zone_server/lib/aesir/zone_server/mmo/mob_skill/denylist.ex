defmodule Aesir.ZoneServer.Mmo.MobSkill.Denylist do
  @moduledoc """
  Explicit denylist of rAthena skill ids that resolve in the real skill
  catalog (`Skill.Catalog.by_id/1` with an active module) but are known-broken
  when the caster is a mob rather than a player.

  Populated by `MobSkill.SweepTest` (mob-skill-convergence epic), which
  exercises every catalog-resolvable mob-skill row against a real mob caster;
  entries land here instead of a `try/rescue` in the Executor.
  """

  @denied %{
    6 => "SM_PROVOKE cast/4 pattern-matches %{character_id: _}, no mob-caster clause",
    7 => "SM_MAGNUM cast/4 pattern-matches %{character_id: _}, no mob-caster clause",
    8 => "SM_ENDURE cast/4 pattern-matches %{character_id: _}, no mob-caster clause",
    10 => "MG_SIGHT cast/4 pattern-matches %{character_id: _}, no mob-caster clause",
    16 => "MG_STONECURSE cast/4 pattern-matches %{character_id: _}, no mob-caster clause",
    29 => "AL_INCAGI cast/4 pattern-matches %{character_id: _}, no mob-caster clause",
    30 => "AL_DECAGI cast/4 pattern-matches %{character_id: _}, no mob-caster clause",
    51 => "TF_HIDING cast/4 pattern-matches %{character_id: _}, no mob-caster clause",
    61 => "KN_AUTOCOUNTER cast/4 pattern-matches %{character_id: _}, no mob-caster clause",
    72 => "PR_STRECOVERY cast/4 pattern-matches %{character_id: _}, no mob-caster clause",
    73 => "PR_KYRIE cast/4 pattern-matches %{character_id: _}, no mob-caster clause",
    76 => "PR_LEXDIVINA cast/4 pattern-matches %{character_id: _}, no mob-caster clause",
    78 => "PR_LEXAETERNA cast/4 pattern-matches %{character_id: _}, no mob-caster clause",
    80 => "WZ_FIREPILLAR validate/4 requires %{inventory: _} in both clauses (player item check)",
    81 => "WZ_SIGHTRASHER cast/4 pattern-matches %{character_id: _}, no mob-caster clause",
    83 =>
      "WZ_METEOR on_place/1 indexes definition.duration by level-1; mob rows carry levels " <>
        "(seen: 11) past the 10-entry player array, Enum.at returns nil and crashes the add",
    85 =>
      "WZ_VERMILION on_place/1 indexes definition.duration by level-1; mob rows carry " <>
        "levels (seen: 21) past the 10-entry player array, Enum.at returns nil and crashes the add",
    86 => "WZ_WATERBALL cast/4 pattern-matches %{character_id: _}, no mob-caster clause",
    87 => "WZ_ICEWALL validate/4 pattern-matches %{character_id: _}, no mob-caster clause",
    88 => "WZ_FROSTNOVA cast/4 pattern-matches %{character_id: _}, no mob-caster clause",
    90 => "WZ_EARTHSPIKE skill_ratio/1 pattern-matches %{character_id: _}, no mob-caster clause",
    125 =>
      "HT_TALKIEBOX cast/4 always requires the client's staged text-input reply; a mob " <>
        "caster has no text source to satisfy it",
    150 => "TF_BACKSLIDING cast/4 pattern-matches %{character_id: _}, no mob-caster clause",
    255 => "CR_DEVOTION party/devotion semantics are player-only, no mob-caster clause",
    304 =>
      "BD_ADAPTATION requires character_id and applies a player status; " <>
        "there is no mob-caster clause",
    305 =>
      "BD_ENCORE reads PlayerState last_song and re-enters player learned-skill, equipment, " <>
        "cost, and cooldown validation; mobs have none of that replay state",
    306 =>
      "BD_LULLABY requires a PlayerState snapshot and partner lookup; there is no mob-caster clause",
    307 =>
      "BD_RICHMANKIM requires a PlayerState snapshot and partner lookup; there is no mob-caster clause",
    308 =>
      "BD_ETERNALCHAOS requires a PlayerState snapshot and partner lookup; there is no mob-caster clause",
    309 =>
      "BD_DRUMBATTLEFIELD requires a PlayerState snapshot and partner lookup; there is no mob-caster clause",
    310 =>
      "BD_RINGNIBELUNGEN requires a PlayerState snapshot and partner lookup; there is no mob-caster clause",
    311 =>
      "BD_ROKISWEIL requires a PlayerState snapshot and partner lookup; there is no mob-caster clause",
    312 =>
      "BD_INTOABYSS requires a PlayerState snapshot and partner lookup; there is no mob-caster clause",
    313 =>
      "BD_SIEGFRIED requires a PlayerState snapshot and partner lookup; there is no mob-caster clause",
    319 => "BA_WHISTLE requires a PlayerState party snapshot; there is no mob-caster clause",
    320 =>
      "BA_ASSASSINCROSS requires a PlayerState party snapshot; there is no mob-caster clause",
    321 => "BA_POEMBRAGI requires a PlayerState party snapshot; there is no mob-caster clause",
    322 => "BA_APPLEIDUN requires a PlayerState party snapshot; there is no mob-caster clause",
    327 => "DC_HUMMING requires a PlayerState party snapshot; there is no mob-caster clause",
    328 => "DC_DONTFORGETME requires a PlayerState enemy snapshot; there is no mob-caster clause",
    329 => "DC_FORTUNEKISS requires a PlayerState party snapshot; there is no mob-caster clause",
    330 =>
      "DC_SERVICEFORYOU requires a PlayerState party snapshot; there is no mob-caster clause",
    1011 =>
      "DC_WINKCHARM reads PlayerState caster level and applies a player-origin status; there is no mob-caster clause"
  }

  @doc "Whether `skill_id` is denylisted for mob casting."
  @spec denied?(integer()) :: boolean()
  def denied?(skill_id), do: reason_for(skill_id) != nil

  @doc "The one-line reason `skill_id` is denylisted, or `nil` if it is not."
  @spec reason_for(integer()) :: String.t() | nil
  def reason_for(skill_id), do: Map.get(@denied, skill_id)
end
