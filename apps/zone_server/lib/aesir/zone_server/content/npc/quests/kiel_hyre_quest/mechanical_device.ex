defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.MechanicalDevice do
  @moduledoc """
  The factory keycard reader controls access to the inner room.

  ## Behavior

  - Accepts the Red Keycard name at the appropriate quest stage and transfers its holder inside.

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
        x: 166,
        y: 223,
        dir: 0,
        sprite: 111,
        name: "Mechanical Device",
        scope: :shared,
        unique_name: "KHKeyardReader"
      },
      %{
        map: "kh_dun01",
        x: 162,
        y: 206,
        dir: 0,
        sprite: 111,
        name: "Mechanical Device",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    quest_stage = get_char_var(ctx, :KielHyreQuest, 0)

    cond do
      quest_stage <= 38 or quest_stage >= 44 ->
        describe_reader(ctx) |> close()

      quest_stage == 40 and count_item(ctx, 7496) >= 1 ->
        insert_keycard(ctx)

      true ->
        ctx
    end
  end

  defp describe_reader(ctx) do
    ctx
    |> mes("^3355FFYou encounter")
    |> mes("a mechanical device.")
    |> mes("It looks like it can be")
    |> mes("operated by inserting the")
    |> mes("correct keycard into the slot.^000000")
  end

  defp insert_keycard(ctx) do
    {ctx, keycard_name} = ctx |> describe_reader() |> next() |> input(:string)
    ctx = set_local(ctx, :"KHInput$", keycard_name)

    if get_local(ctx, :"KHInput$", "") == "Red Keycard" do
      ctx
      |> mes("^3355FFThe door opens once")
      |> mes("you insert the Red Keycard.^000000")
      |> close()
      |> warp("kh_dun01", 170, 227)
    else
      ctx |> mes("^3355FFNothing happened.^000000") |> close()
    end
  end
end
