defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.BigDoor77108 do
  @moduledoc """
  The third big door accepts a Black Keycard to open its passage.

  ## Behavior

  - Consumes a Black Keycard after its exact name is entered.
  - Enables the passage and records the door as open; other attempts leave it locked.

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
        x: 77,
        y: 108,
        dir: 0,
        sprite: 111,
        name: "Big Door",
        scope: :shared,
        unique_name: "Big Door#BigDoorKHQ3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_npc_var(ctx, "KHDoor3Opened", 0) == 0 do
      try_keycard(ctx)
    else
      ctx |> mes("^3355FFThe door is open.^000000") |> close()
    end
  end

  defp try_keycard(ctx) do
    {ctx, keycard_name} =
      ctx
      |> mes("^3355FFThe door is locked,")
      |> mes("but there is a narrow")
      |> mes("slot next to the doorknob.^000000")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"KHInput$", keycard_name)

    if get_local(ctx, :"KHInput$", "") == "Black Keycard" and count_item(ctx, 7506) >= 1 do
      ctx
      |> mes("^3355FFYou insert the")
      |> mes("Black Keycard into the")
      |> mes("slot, and successfully")
      |> mes("unlock and open the door.^000000")
      |> delitem(7506, 1)
      |> donpcevent("Big_Door_3_Warp::OnEnable")
      |> enablenpc("Big_Door_3_Warp")
      |> set_npc_var("KHDoor3Opened", 1)
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
