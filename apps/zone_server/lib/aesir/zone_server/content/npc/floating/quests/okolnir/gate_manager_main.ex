defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.GateManagerMain do
  @moduledoc """
  Watches the gate mobs of each Okolnir castle and starts the next mob wave once
  a castle's gate mobs are all dead.

  ## Behavior

  - Ignores direct interaction.
  - On a gate mob's death it compares the castle's accumulated mob kills with the
    expected kill count and, when both match and no gate mob is left alive,
    enables the castle's miro mob controller.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Joseph
    - L0ne_W0lf
    - Toshiro90
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/okolnir.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_qaru01",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#Gate_manager_aru01"
      },
      %{
        map: "que_qaru02",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#Gate_manager_aru02"
      },
      %{
        map: "que_qaru03",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#Gate_manager_aru03"
      },
      %{
        map: "que_qaru04",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#Gate_manager_aru04"
      },
      %{
        map: "que_qaru05",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#Gate_manager_aru05"
      },
      %{
        map: "que_qsch01",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#Gate_manager_sch01"
      },
      %{
        map: "que_qsch02",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#Gate_manager_sch02"
      },
      %{
        map: "que_qsch03",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#Gate_manager_sch03"
      },
      %{
        map: "que_qsch04",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#Gate_manager_sch04"
      },
      %{
        map: "que_qsch05",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#Gate_manager_sch05"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FOkolnir
  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnMyMobDead", ctx) do
    {ctx, castle} = FOkolnir.call(ctx, [])

    if gate_mobs_killed?(ctx, castle) and gate_mobs_cleared?(ctx, castle) do
      donpcevent(ctx, "#gq_miromob2_#{castle}::OnEnable")
    else
      ctx
    end
  end

  defp gate_mobs_killed?(ctx, castle) do
    getd(ctx, "$@gqse_#{castle}_miro") == getd(ctx, "$@gqse_#{castle}_pcc")
  end

  defp gate_mobs_cleared?(ctx, castle) do
    mobcount(ctx, "que_q#{castle}", "#Gate_manager_#{castle}::OnMyMobDead") == 0
  end
end
