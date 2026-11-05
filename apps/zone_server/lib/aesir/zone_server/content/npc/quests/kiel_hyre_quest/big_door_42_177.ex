defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.BigDoor42177 do
  @moduledoc """
  The fourth big door opens when supplied with two Black Keycards.

  ## Behavior

  - Prompts for the Black Keycard phrase while locked.
  - Consumes two cards, enables the doorway warp, and records the opened door.

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
        x: 42,
        y: 177,
        dir: 0,
        sprite: 111,
        name: "Big Door",
        scope: :shared,
        unique_name: "Big Door#BigDoorKHQ4"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_npc_var(ctx, "KHDoor4Opened", 0) == 0 do
      unlock_door(ctx)
    else
      ctx |> mes("^3355FFThe door is open.^000000") |> close()
    end
  end

  defp unlock_door(ctx) do
    {ctx, keycard_name} =
      ctx
      |> mes("^3355FFThe door is locked,")
      |> mes("but there is a narrow")
      |> mes("slot next to the doorknob.^000000")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"KHInput$", keycard_name)

    if get_local(ctx, :"KHInput$", "") == "Black Keycard" and count_item(ctx, 7506) >= 2 do
      ctx
      |> mes("^3355FFYou insert the")
      |> mes("Black Keycard into the")
      |> mes("slot, and successfully")
      |> mes("unlock and open the door.^000000")
      |> delitem(7506, 2)
      |> donpcevent("Big_Door_4_Warp::OnEnable")
      |> enablenpc("Big_Door_4_Warp")
      |> set_npc_var("KHDoor4Opened", 1)
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
