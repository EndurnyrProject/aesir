defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.EntranceDevice do
  @moduledoc """
  A keycard device controls access to the lower robot factory.

  ## Behavior

  - Requires a Luxurious Keycard and its exact name before revealing the stairs.
  - Transfers the adventurer downstairs or lets the opened door close.

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
        x: 44,
        y: 203,
        dir: 0,
        sprite: 111,
        name: "Entrance Device",
        scope: :shared,
        unique_name: "KHAccess"
      },
      %{
        map: "kh_dun01",
        x: 36,
        y: 195,
        dir: 0,
        sprite: 111,
        name: "Entrance Device",
        scope: :shared,
        unique_name: "Entrance Device#khd1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("^3355FFYou encounter")
      |> mes("a mechanical device.")
      |> mes("It looks like it can be")
      |> mes("operated by inserting the")
      |> mes("correct keycard into the slot.^000000")

    if count_item(ctx, 7509) < 1 do
      close(ctx)
    else
      read_keycard(ctx)
    end
  end

  defp read_keycard(ctx) do
    {ctx, keycard_name} = ctx |> next() |> input(:string)
    ctx = set_local(ctx, :"KHInput$", keycard_name)

    if get_local(ctx, :"KHInput$", "") == "Luxurious Keycard" do
      offer_stairs(ctx)
    else
      ctx
      |> mes("^3355FFYou try to push the")
      |> mes("door open with all")
      |> mes("your might, but fail")
      |> mes("to make it budge.^000000")
      |> close()
    end
  end

  defp offer_stairs(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFAs you insert the")
      |> mes("Luxurious Keycard")
      |> mes("into the keycard slot,")
      |> mes("the door swings open")
      |> mes("to reveal a long flight")
      |> mes("of descending stairs.^000000")
      |> next()
      |> select(["Descend Stairs", "Cancel"])

    case choice do
      1 ->
        warp(ctx, "kh_dun02", 41, 198)

      2 ->
        ctx
        |> mes("^3355FFIt looks like this door")
        |> mes("has automatically closed")
        |> mes("after the preprogrammed")
        |> mes("time limit has elapsed.^000000")
        |> close()

      _ ->
        ctx
    end
  end
end
