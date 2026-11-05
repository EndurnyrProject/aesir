defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.BigDoor17440 do
  @moduledoc """
  A locked door accepts the Toy Key to activate a temporary passage.

  ## Behavior

  - Requires the exact key name and consumes a held Toy Key.
  - Enables the linked warp and records that the door is open.

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
        map: "kh_kiehl01",
        x: 174,
        y: 40,
        dir: 0,
        sprite: 111,
        name: "Big Door",
        scope: :shared,
        unique_name: "Big Door#BigDoorKHQ2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_npc_var(ctx, "KHDoor2Opened", 0) == 0 do
      unlock_door(ctx)
    else
      ctx |> mes("^3355FFThe door is open.^000000") |> close()
    end
  end

  defp unlock_door(ctx) do
    {ctx, key_name} =
      ctx
      |> mes("^3355FFThe door is locked,")
      |> mes("but there is a small")
      |> mes("keyhole next to the knob.^000000")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"KHInput$", key_name)

    if get_local(ctx, :"KHInput$", "") == "Toy Key" and count_item(ctx, 7505) >= 1 do
      ctx
      |> mes("^3355FFYou insert the key into")
      |> mes("the keyhole, and the door")
      |> mes("unlocks with a click as")
      |> mes("you turn the key.^000000")
      |> delitem(7505, 1)
      |> donpcevent("Big_Door_2_Warp::OnEnable")
      |> enablenpc("Big_Door_2_Warp")
      |> set_npc_var("KHDoor2Opened", 1)
      |> close()
    else
      ctx
      |> mes("^3355FFYou try to push the")
      |> mes("door open with all")
      |> mes("your might, but fail")
      |> mes("to make it budge.^000000")
      |> close()
    end
  end
end
