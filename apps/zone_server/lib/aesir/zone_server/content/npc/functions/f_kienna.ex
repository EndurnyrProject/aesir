defmodule Aesir.ZoneServer.Content.Npc.Functions.FKienna do
  @moduledoc """
  Runs Kienna's Close Confine blocking exercise for Rogues in the training arena.

  ## Behavior

  - At the training step, the player predicts ten random moves; each correct block earns a
    point and the result is graded from F- to S.
  - Six or more blocks completes the training and sends the player back to the Rogue Guild;
    otherwise the player can retry from the arena entrance or return to the guild.
  - A player who left mid-exercise restarts it; finished or unrelated players are returned to
    the Rogue Guild.
  - Every path ends the calling script.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - 2Spiritual Kid
    - DracoRPG
    - L0ne_W0lf
    - Samuray22
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl, warn: false

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @doc "Runs the exercise for the Kienna placement suffix in `args`; always ends the script."
  @spec call(Ctx.t(), [term()]) :: no_return()
  def call(ctx, args) do
    kienna = Rathena.concat("Kienna#", Enum.at(args, 0, 0))

    ctx =
      case get_char_var(ctx, :ROG_SK, 0) do
        6 -> train(ctx, kienna)
        7 -> restart(ctx, kienna)
        8 -> already_trained(ctx)
        _ -> send_lost_player_back(ctx)
      end

    throw({:script_end, ctx})
  end

  defp train(ctx, kienna) do
    ctx =
      ctx
      |> donpcevent("#1stmove::OnDisable")
      |> mes("[Kienna]")
      |> mes("Alright, in this")
      |> mes("exercise, you'll need")
      |> mes("to predict which way I'm")
      |> mes("going to move and block")
      |> mes("me from moving, essentially")
      |> mes("immobilizing me. Get ready~")
      |> set_char_var(:ROG_SK, 7)
      |> next()

    {ctx, blocks} = Enum.reduce(1..10, {ctx, 0}, fn _, acc -> attempt_block(acc) end)

    ctx =
      ctx
      |> mes("[Kienna]")
      |> mes("Alright, we're done")
      |> mes("here. You earned a")
      |> grade(blocks)
      |> next()

    if blocks > 5, do: pass(ctx, kienna), else: offer_retry(ctx, kienna)
  end

  defp attempt_block({ctx, blocks}) do
    move = Enum.random(1..3)

    {ctx, choice} =
      select(ctx, ["Block her to the Left", "Block her to the Right", "Block her retreat"])

    {ctx, blocks} =
      if choice == move do
        ctx =
          ctx
          |> mes("[Kienna]")
          |> mes("Huh...?")
          |> mes("You blocked me!")
          |> mes("Very nice work~")
          |> specialeffect(:potion1)
          |> specialeffect2(:potion7)

        {ctx, blocks + 1}
      else
        ctx =
          ctx
          |> mes("[Kienna]")
          |> mes("Sorry, but I wasn't")
          |> mes("moving in that direction.")
          |> mes("Your block attempt failed...")

        {ctx, blocks}
      end

    {next(ctx), blocks}
  end

  defp grade(ctx, 10) do
    ctx |> mes("training grade of ''^0000FFS^000000.''") |> mes("That's a perfect score!")
  end

  defp grade(ctx, 9) do
    ctx |> mes("training grade of ''^0000FFA^000000.''") |> mes("You're really good at this!")
  end

  defp grade(ctx, 8) do
    ctx |> mes("training grade of ''^0000FFB +^000000.''") |> mes("That's very commendable!")
  end

  defp grade(ctx, 7) do
    ctx |> mes("training grade of ''^0000FFB^000000.''") |> mes("That's very nice work~")
  end

  defp grade(ctx, 6) do
    ctx
    |> mes("training grade of ''^0000FFC +^000000.''")
    |> mes("Not too bad, but you")
    |> mes("just barely passed!")
  end

  defp grade(ctx, 5), do: mes(ctx, "training grade of ''^FF0000C^000000.''")
  defp grade(ctx, 4), do: mes(ctx, "training grade of ''^FF0000D+^000000.''")
  defp grade(ctx, 3), do: mes(ctx, "training grade of ''^FF0000D^000000.''")
  defp grade(ctx, 2), do: mes(ctx, "training grade of ''^FF0000F^000000.''")
  defp grade(ctx, 1), do: mes(ctx, "training grade of ''^FF0000F -^000000.''")

  defp grade(ctx, 0) do
    ctx
    |> mes("training grade of...")
    |> mes("Actually, I'm not able")
    |> mes("to calculate it. What")
    |> mes("could have happened?!")
  end

  defp pass(ctx, kienna) do
    ctx
    |> mes("[Kienna]")
    |> mes("I'm happy to say that")
    |> mes("you've completed your")
    |> mes("training! Let me send")
    |> mes("you back to Thor Greg")
    |> mes("now so that you can finish")
    |> mes("learning ^FF0000Close Confine^000000.")
    |> set_char_var(:ROG_SK, 8)
    |> disablenpc(kienna)
    |> donpcevent("#1st5min::OnDisable")
    |> enablenpc("#1strecog")
    |> close()
    |> return_to_guild()
  end

  defp offer_retry(ctx, kienna) do
    {ctx, choice} =
      ctx
      |> mes("[Kienna]")
      |> mes("Hm. With this grade,")
      |> mes("I don't think you're")
      |> mes("quite ready to finish")
      |> mes("learning Close Confine.")
      |> mes("Would you like to try the")
      |> mes("training exercise again?")
      |> next()
      |> select(["Yes!", "No, thanks."])

    if choice == 1 do
      ctx
      |> disablenpc(kienna)
      |> donpcevent("#1stmove::OnEnable")
      |> set_char_var(:ROG_SK, 6)
      |> warp("prt_are01", 150, 150)
    else
      ctx
      |> disablenpc(kienna)
      |> donpcevent("#1st5min::OnDisable")
      |> enablenpc("#1strecog")
      |> set_char_var(:ROG_SK, 6)
      |> return_to_guild()
    end
  end

  defp restart(ctx, kienna) do
    ctx
    |> mes("[Kienna]")
    |> mes("You must have canceled")
    |> mes("your training in the middle")
    |> mes("of the exercise. I'm sorry,")
    |> mes("but you'll have to start")
    |> mes("from the very beginning")
    |> mes("of this training.")
    |> set_char_var(:ROG_SK, 6)
    |> close()
    |> disablenpc(kienna)
    |> donpcevent("#1stmove::OnEnable")
    |> warp("prt_are01", 150, 150)
  end

  defp already_trained(ctx) do
    ctx
    |> mes("[Kienna]")
    |> mes("You've already completed")
    |> mes("the training exercise for")
    |> mes("the Close Confine skill.")
    |> mes("You no longer have need")
    |> mes("for my assistance.")
    |> close()
    |> return_to_guild()
  end

  defp send_lost_player_back(ctx) do
    ctx
    |> mes("[Kienna]")
    |> mes("I'm sorry, but I don't")
    |> mes("think you belong here.")
    |> mes("Let me send you to the")
    |> mes("Rogue Guild if you're lost...")
    |> close()
    |> return_to_guild()
  end

  defp return_to_guild(ctx) do
    ctx |> donpcevent("Waiting Room#rogue10::OnEnable") |> warp("in_rogue", 264, 124)
  end
end
