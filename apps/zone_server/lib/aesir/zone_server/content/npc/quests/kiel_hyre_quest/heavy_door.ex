defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.HeavyDoor do
  @moduledoc """
  A heavy factory door accepts a Blue Keycard phrase during the rescue investigation.

  ## Behavior

  - Offers attempts to open the door during the early quest stages.
  - Transfers the adventurer to the academy after the correct phrase during the active rescue stages.

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
        map: "kh_dun01",
        x: 235,
        y: 48,
        dir: 0,
        sprite: 111,
        name: "Heavy Door",
        scope: :shared,
        unique_name: "HeavyDoorKHQ1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    quest_stage = get_char_var(ctx, :KielHyreQuest, 0)

    cond do
      quest_stage < 38 ->
        attempt_locked_door(ctx)

      quest_stage < 46 ->
        offer_keycard_entry(ctx)

      true ->
        ctx
        |> mes("^3355FFThis is an incredibly")
        |> mes("heavy door that is tightly")
        |> mes("closed. You won't be able to")
        |> mes("open it through brute force.^000000")
        |> close()
    end
  end

  defp attempt_locked_door(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThere is a large, heavy")
      |> mes("door infront of you.^000000")
      |> next()
      |> select(["Open Door", "Cancel"])

    case choice do
      1 ->
        {ctx, keycard_name} = input(ctx, :string)
        ctx |> set_local(:"KHInput$", keycard_name) |> fail_to_open()

      2 ->
        ctx
        |> mes("^3355FFyou decided to leave")
        |> mes("this door alone until")
        |> mes("you can figure out")
        |> mes("how to open it^000000")
        |> close()

      _ ->
        ctx
    end
  end

  defp offer_keycard_entry(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThere is a large, heavy")
      |> mes("door in front of you.^000000")
      |> next()
      |> select(["Open Door", "Cancel"])

    case choice do
      1 ->
        read_keycard(ctx)

      2 ->
        ctx
        |> mes("^3355FFYou decided to leave")
        |> mes("this door alone until")
        |> mes("you can figure out")
        |> mes("how you can open it.^000000")
        |> close()

      _ ->
        ctx
    end
  end

  defp read_keycard(ctx) do
    {ctx, keycard_name} = input(ctx, :string)
    ctx = set_local(ctx, :"KHInput$", keycard_name)

    if get_local(ctx, :"KHInput$", "") == "Blue Keycard" do
      ctx
      |> mes("^3355FFYou've successfully")
      |> mes("opened the door.")
      |> close()
      |> warp("kh_school", 119, 144)
    else
      fail_to_open(ctx)
    end
  end

  defp fail_to_open(ctx) do
    ctx
    |> mes("^3355FFYou try to push the")
    |> mes("door open with all")
    |> mes("your might, but fail")
    |> mes("to make it budge.^000000")
    |> close()
  end
end
