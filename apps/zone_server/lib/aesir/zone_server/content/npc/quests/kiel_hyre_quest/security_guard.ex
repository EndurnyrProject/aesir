defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.SecurityGuard do
  @moduledoc """
  The academy security guard checks delivery details before allowing entry.

  ## Behavior

  - Verifies Lecollane and Culinary Wine for the initial delivery.
  - Allows returning visitors during the early academy quest stages and refuses other visitors.

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
        map: "yuno_fild08",
        x: 158,
        y: 194,
        dir: 6,
        sprite: 852,
        name: "Security Guard",
        scope: :shared,
        unique_name: "KHAGuard"
      },
      %{
        map: "yuno_fild08",
        x: 158,
        y: 183,
        dir: 7,
        sprite: 852,
        name: "Security Guard",
        scope: :shared,
        unique_name: "Security Guard#2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    quest_stage = get_char_var(ctx, :KielHyreQuest, 0)

    cond do
      quest_stage < 2 or quest_stage > 31 ->
        ctx |> explain_restriction() |> close()

      quest_stage == 2 ->
        verify_delivery(ctx)

      quest_stage < 32 ->
        ctx
        |> mes("[Security Guard]")
        |> mes("Oh, did you have")
        |> mes("other business inside")
        |> mes("the academy? I remember")
        |> mes("you from before, so there")
        |> mes("shouldn't be any problems")
        |> mes("letting you back inside...")
        |> close()
        |> warp("kh_school", 71, 155)

      true ->
        ctx
    end
  end

  defp explain_restriction(ctx) do
    ctx
    |> mes("[Security Guard]")
    |> mes("I'm sorry, but if you aren't")
    |> mes("associated with this institution,")
    |> mes("then you're not authorized to")
    |> mes("enter the ^FF0000Kiel Hyre Academy^000000.")
    |> mes("Please leave if you don't have")
    |> mes("an appointment with the staff.")
  end

  defp verify_delivery(ctx) do
    {ctx, choice} =
      ctx
      |> explain_restriction()
      |> next()
      |> select(["I'm here for a delivery.", "......"])

    case choice do
      1 ->
        ask_recipient(ctx)

      2 ->
        ctx
        |> mes("[Security Guard]")
        |> mes("If you don't have")
        |> mes("an appoointment, then")
        |> mes("don't loiter around in")
        |> mes("front of the academy!")
        |> close()

      _ ->
        ctx
    end
  end

  defp ask_recipient(ctx) do
    {ctx, recipient} =
      ctx
      |> mes("[Security Guard]")
      |> mes("You're here to deliver")
      |> mes("something? Okay, just give")
      |> mes("me the recipient's ^FF0000name^000000,")
      |> mes("followed by the ^FF0000item^000000 being")
      |> mes("delivered, and I'll verify it")
      |> mes("before letting you inside.")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"KHDelivery$", recipient)

    if get_local(ctx, :"KHDelivery$", "") != "Lecollane" do
      ctx
      |> mes("[Security Guard]")
      |> mes("You're here to deliver some")
      |> mes("Wine to...to who? What was")
      |> mes("the name? I...I don't think")
      |> mes("we have anybody in the")
      |> mes("academy named #{get_local(ctx, :"KHDelivery$", "")}")
      |> close()
    else
      ask_delivery_item(ctx)
    end
  end

  defp ask_delivery_item(ctx) do
    {ctx, delivery_item} = input(ctx, :string)
    ctx = set_local(ctx, :"KHDelivery$", delivery_item)

    if get_local(ctx, :"KHDelivery$", "") != "Culinary Wine" do
      reject_delivery(ctx)
    else
      admit_delivery(ctx)
    end
  end

  defp reject_delivery(ctx) do
    ctx
    |> mes("[Security Guard]")
    |> mes("So you're here to make")
    |> mes("a delivery to Mrs. Lecollane?")
    |> mes("What is it you've brought for")
    |> mes("her? Some ^3355FF#{get_local(ctx, :"KHDelivery$", "")}^000000?")
    |> next()
    |> mes("[Security Guard]")
    |> mes("Let me buzz her first,")
    |> mes("and check to make sure")
    |> mes("that she's been expecting")
    |> mes("you. Let's see now...")
    |> next()
    |> mes("......")
    |> mes(".........")
    |> mes("............")
    |> next()
    |> mes("[Security Guard]")
    |> mes("Huh. Mrs Lecollane")
    |> mes("is expecting a delivery,")
    |> mes("but not the item that you")
    |> mes("say that you've brought for")
    |> mes("her. You might want to check")
    |> mes("to see if there's been a mixup...")
    |> close()
  end

  defp admit_delivery(ctx) do
    ctx
    |> mes("[Security Guard]")
    |> mes("Alright....")
    |> mes("So you're here to")
    |> mes("deliver a bottle of")
    |> mes("Wine to Mrs. Lecollane?")
    |> mes("Let me buzz her, and get")
    |> mes("this confirmed real quickly.")
    |> next()
    |> mes("......")
    |> mes(".........")
    |> mes("............")
    |> next()
    |> mes("[Security Guard]")
    |> mes("Okay, everything looks")
    |> mes("good. Mrs. Lecollane")
    |> mes("has been expecting you.")
    |> mes("I guess you can enter.")
    |> close()
    |> warp("kh_school", 71, 155)
  end
end
