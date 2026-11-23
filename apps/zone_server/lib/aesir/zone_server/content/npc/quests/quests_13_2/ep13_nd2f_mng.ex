defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.Ep13Nd2fMng do
  @moduledoc """
  Resets the Yggdrasil dungeon floor 2 puzzle when another NPC fires its reset event.

  ## Behavior

  - Re-enables the puzzle warps and disables the second-stage warps on its reset event.
  - The GM-only password reset menu is not carried over.

  ## Credits

  - Original from rAthena, authors and contributors:
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
      %{map: "nyd_dun02", x: 1, y: 1, dir: 0, sprite: 844, name: "ep13_nd2f_mng", scope: :shared}
    ]

  @impl true
  def on_event("OnReset", ctx), do: ev_onreset(ctx)

  @impl true
  def on_talk(ctx), do: ctx

  def ev_onreset(ctx) do
    ctx
    |> donpcevent("ep13_warp_s1::OnEnable")
    |> donpcevent("ep13_warp_s3::OnEnable")
    |> donpcevent("ep13_warp_11::OnEnable")
    |> donpcevent("ep13_warp_13::OnEnable")
    |> donpcevent("ep13_warp_14::OnEnable")
    |> donpcevent("ep13_warp_21::OnEnable")
    |> donpcevent("ep13_warp_22::OnEnable")
    |> donpcevent("ep13_warp_24::OnEnable")
    |> donpcevent("ep13_warp_25::OnEnable")
    |> donpcevent("ep13_warp_26::OnEnable")
    |> donpcevent("ep13_warp_31::OnEnable")
    |> donpcevent("ep13_warp_33::OnEnable")
    |> donpcevent("ep13_warp_35::OnEnable")
    |> donpcevent("ep13_warp_41::OnEnable")
    |> donpcevent("ep13_warp_42::OnEnable")
    |> donpcevent("ep13_warp_43::OnEnable")
    |> donpcevent("ep13_warp_45::OnEnable")
    |> donpcevent("ep13_warp_46::OnEnable")
    |> donpcevent("ep13_warp_52::OnEnable")
    |> donpcevent("ep13_warp_55::OnEnable")
    |> donpcevent("ep13_warp_56::OnEnable")
    |> donpcevent("ep13_warp_61::OnEnable")
    |> donpcevent("ep13_warp_62::OnEnable")
    |> donpcevent("ep13_warp_64::OnEnable")
    |> donpcevent("ep13_warp_65::OnEnable")
    |> donpcevent("ep13_warp_66::OnEnable")
    |> donpcevent("ep13_warp_71::OnEnable")
    |> donpcevent("ep13_warp_72::OnEnable")
    |> donpcevent("ep13_warp_73::OnEnable")
    |> donpcevent("ep13_warp_75::OnEnable")
    |> donpcevent("ep13_warp_76::OnEnable")
    |> donpcevent("ep13_warp_81::OnEnable")
    |> donpcevent("ep13_warp_82::OnEnable")
    |> donpcevent("ep13_warp_83::OnEnable")
    |> donpcevent("ep13_warp_84::OnEnable")
    |> donpcevent("ep13_warp_85::OnEnable")
    |> donpcevent("ep13_warp_91::OnEnable")
    |> donpcevent("ep13_warp_92::OnEnable")
    |> donpcevent("ep13_warp_93::OnEnable")
    |> donpcevent("ep13_warp_94::OnEnable")
    |> donpcevent("ep13_warp_95::OnEnable")
    |> donpcevent("ep13_warp_e1::OnEnable")
    |> donpcevent("ep13_warp_e2::OnEnable")
    |> donpcevent("ep13_warp_e3::OnEnable")
    |> donpcevent("ep13_warp_22_2::OnDisable")
    |> donpcevent("ep13_warp_24_2::OnDisable")
    |> donpcevent("ep13_warp_43_2::OnDisable")
    |> donpcevent("ep13_warp_45_2::OnDisable")
    |> donpcevent("ep13_warp_61_2::OnDisable")
    |> donpcevent("ep13_warp_65_2::OnDisable")
    |> donpcevent("ep13_warp_81_2::OnDisable")
    |> donpcevent("ep13_warp_83_2::OnDisable")
    |> donpcevent("ep13_warp_85_2::OnDisable")
  end
end
