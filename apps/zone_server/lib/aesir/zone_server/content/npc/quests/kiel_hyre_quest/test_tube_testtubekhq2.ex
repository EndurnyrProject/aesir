defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.TestTubeTesttubekhq2 do
  @moduledoc """
  A captive old man reveals a number sequence when given his secret name.

  ## Behavior

  - Prompts for the captive's identity at the cottage investigation stage.
  - Reveals 4772961, clears the poem variables, and advances the quest for the correct answer.
  - Shows the captive without further interaction after that stage.

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
        map: "kh_vila",
        x: 185,
        y: 68,
        dir: 0,
        sprite: 111,
        name: "Test Tube::TestTubeKHQ2",
        scope: :shared,
        unique_name: "TestTubeKHQ2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    quest_stage = get_char_var(ctx, :KielHyreQuest, 0)

    cond do
      quest_stage > 28 ->
        ctx
        |> mes("^3355FFA strange looking,")
        |> mes("wizened old man is")
        |> mes("held within this test tube.^000000")
        |> close()

      quest_stage == 28 ->
        offer_button(ctx)

      quest_stage >= 30 ->
        recall_number(ctx)

      true ->
        ctx
    end
  end

  defp offer_button(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFA strange looking,")
      |> mes("wizened old man is")
      |> mes("held within this test tube.")
      |> mes("There is a small red button")
      |> mes("right underneath the test tube.^000000")
      |> next()
      |> select(["Press Button", "Investigate Further"])

    case choice do
      1 ->
        ask_identity(ctx)

      2 ->
        ctx
        |> mes("^3355FFLet's investigate")
        |> mes("this area a little")
        |> mes("more first.^000000")
        |> close()

      _ ->
        ctx
    end
  end

  defp ask_identity(ctx) do
    {ctx, identity} =
      ctx
      |> mes("[???]")
      |> mes("H-hello...? C-can you")
      |> mes("hear me? I don't recognize")
      |> mes("you... But... Maybe I forgot?")
      |> mes("Wait, wait. If you're my friend,")
      |> mes("then you know what to call me,")
      |> mes("right? Do you know what I am?")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"KHInput$", identity)

    if get_local(ctx, :"KHInput$", "") == "little lost devil" do
      reveal_number(ctx)
    else
      ctx
      |> mes("[???]")
      |> mes("No... No...")
      |> mes("That's not right.")
      |> mes("I don't think we")
      |> mes("were friends. No...")
      |> close()
    end
  end

  defp reveal_number(ctx) do
    ctx
    |> mes("[???]")
    |> mes("Heh... Heh heh...")
    |> mes("He knows... Hey, you")
    |> mes("have to remember these")
    |> mes("numbers, okay? D-don't")
    |> mes("forget, they'll be important...")
    |> mes(
      "^FF00004^000000, ^FF00007^000000, ^FF00007^000000, ^FF00002^000000, ^FF00009^000000, ^FF00006^000000, ^FF00001^000000. That's all..."
    )
    |> next()
    |> mes("^3355FF4772961^000000")
    |> mes("^3355FFWhat could^000000")
    |> mes("^3355FFthose numbers^000000")
    |> mes("^3355FFpossibly mean?^000000")
    |> set_char_var(:KHCottagePoem1, 0)
    |> set_char_var(:KHCottagePoem2, 0)
    |> set_char_var(:KielHyreQuest, 30)
    |> close()
  end

  defp recall_number(ctx) do
    if count_item(ctx, 7491) > 0 and count_item(ctx, 7492) > 0 do
      ctx
      |> mes("^3355FFWhat could the")
      |> mes("number 4772961")
      |> mes("mean? For now, you've")
      |> mes("found everything that")
      |> mes("you need from this place,")
      |> mes("so you should return to Elly.^000000")
      |> close()
    else
      ctx
      |> mes("^3355FFWhat could the")
      |> mes("number 4772961")
      |> mes("mean? For now, you'd")
      |> mes("better search this cottage")
      |> mes("for any clues you can find...^000000")
      |> close()
    end
  end
end
