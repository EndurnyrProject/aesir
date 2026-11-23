defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAirship.Lab03 do
  @moduledoc """
  Guards the laboratory archive with a password challenge.

  ## Behavior

  - Denies access or starts the password challenge according to quest progress.
  - Advances the quest after a correct guess and resets access after five attempts.

  ## Credits

  - Original from rAthena, authors and contributors:
    - Samuray22
    - SinSloth
    - L0ne_W0lf
    - brianluau
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ein_in01",
        x: 261,
        y: 35,
        dir: 0,
        sprite: 139,
        name: "lab03",
        scope: :shared,
        unique_name: "lab03#heart",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch_", ctx) do
    case get_char_var(ctx, :lhz_heart, 0) do
      9 ->
        ctx
        |> mes("[Security System]")
        |> mes("^FF0000Unauthorized person")
        |> mes("detected. Password")
        |> mes("Checker not detected.")
        |> mes("Access denied.^000000")
        |> close()

      10 ->
        ctx
        |> mes("[Security System]")
        |> mes("^FF0000Enter the 3 digit password.")
        |> mes("You will be allowed 5 tries")
        |> mes("within 3 minutes to enter")
        |> mes("the correct password, or")
        |> mes("the password will reset.^000000")
        |> next()
        |> mes("[Password Checker]")
        |> mes("^333333Hint:")
        |> mes("Do not use the")
        |> mes("number 0, and do")
        |> mes("not enter any number")
        |> mes("more than once. Make")
        |> mes("sure the password is 3 digits.")
        |> generate_password()
        |> check_guesses()

      _ ->
        ctx
    end
  end

  @impl true
  def on_talk(ctx), do: ctx

  defp generate_password(ctx) do
    if get_local(ctx, :yagu100, 0) == get_local(ctx, :yagu10, 0) or
         get_local(ctx, :yagu100, 0) == get_local(ctx, :yagu1, 0) or
         get_local(ctx, :yagu10, 0) == get_local(ctx, :yagu1, 0) do
      ctx
      |> set_local(:yagu100, Enum.random(1..9))
      |> set_local(:yagu10, Enum.random(1..9))
      |> set_local(:yagu1, Enum.random(1..9))
      |> generate_password()
    else
      ctx
    end
  end

  defp read_guess(ctx) do
    {ctx, guess} = ctx |> next() |> input(:int)
    ctx = set_local(ctx, :input, guess)

    if guess < 100 or guess > 999 do
      ctx =
        ctx
        |> mes("[Security System]")
        |> mes("^FF0000Error.")
        |> mes("The password entered")
        |> mes("exceeds the number digit")
        |> mes("limit. You must only enter")
        |> mes("3 digit passwords.^000000")
        |> close()

      {:stop, ctx}
    else
      validate_guess(ctx)
    end
  end

  defp validate_guess(ctx) do
    ctx = set_local(ctx, :input100, div(get_local(ctx, :input, 0), 100))
    ctx = set_local(ctx, :input10, div(rem(get_local(ctx, :input, 0), 100), 10))
    ctx = set_local(ctx, :input1, rem(get_local(ctx, :input, 0), 10))

    if get_local(ctx, :input100, 0) + get_local(ctx, :input10, 0) +
         get_local(ctx, :input1, 0) == 0 or
         get_local(ctx, :input100, 0) == get_local(ctx, :input10, 0) or
         get_local(ctx, :input100, 0) == get_local(ctx, :input1, 0) or
         get_local(ctx, :input10, 0) == get_local(ctx, :input1, 0) do
      ctx
      |> mes("[Security System]")
      |> mes("^FF0000Error.")
      |> mes("You cannot enter the")
      |> mes("number 0, or use any")
      |> mes("other number more than")
      |> mes("once. Please try again.^000000")
      |> read_guess()
    else
      {:ok, ctx}
    end
  end

  defp check_guesses(ctx) do
    case read_guess(ctx) do
      {:stop, ctx} -> ctx
      {:ok, ctx} -> score_guess(ctx)
    end
  end

  defp score_guess(ctx) do
    ctx = ctx |> set_local(:retry, get_local(ctx, :retry, 0) + 1) |> mes("[Security System]")

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("^ff0000", char_name(ctx, 0)), "^000000"))
      |> mes("has entered the following:")

    ctx =
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat(
            Rathena.concat(
              Rathena.concat(
                Rathena.concat(
                  Rathena.concat("^0000ff", get_local(ctx, :input100, 0)),
                  "^000000 - ^0000ff"
                ),
                get_local(ctx, :input10, 0)
              ),
              "^000000 - ^0000ff"
            ),
            get_local(ctx, :input1, 0)
          ),
          "^000000."
        )
      )
      |> mes("Please wait for authorization to complete.")
      |> next()

    ctx =
      set_local(
        ctx,
        :strike,
        Rathena.bool_int(get_local(ctx, :yagu100, 0) == get_local(ctx, :input100, 0)) +
          Rathena.bool_int(get_local(ctx, :yagu10, 0) == get_local(ctx, :input10, 0)) +
          Rathena.bool_int(get_local(ctx, :yagu1, 0) == get_local(ctx, :input1, 0))
      )

    ctx =
      set_local(
        ctx,
        :ball,
        Rathena.bool_int(
          get_local(ctx, :yagu100, 0) == get_local(ctx, :input10, 0) or
            get_local(ctx, :yagu100, 0) == get_local(ctx, :input1, 0)
        ) +
          Rathena.bool_int(
            get_local(ctx, :yagu10, 0) == get_local(ctx, :input100, 0) or
              get_local(ctx, :yagu10, 0) == get_local(ctx, :input1, 0)
          ) +
          Rathena.bool_int(
            get_local(ctx, :yagu1, 0) == get_local(ctx, :input100, 0) or
              get_local(ctx, :yagu1, 0) == get_local(ctx, :input10, 0)
          )
      )

    if get_local(ctx, :strike, 0) == 3 do
      authorize(ctx)
    else
      incorrect_guess(ctx)
    end
  end

  defp authorize(ctx) do
    ctx =
      ctx
      |> mes("[Security System]")
      |> mes("Authorization complete.")
      |> mes("Archive access granted.")
      |> next()
      |> mes("^3355FFThe archive door opens,")
      |> mes("revealing a series of")
      |> mes("filed documents. Out")
      |> mes("of all of them, one of the")
      |> mes("files grabs your attention.^000000")
      |> next()
      |> mes("Varmunt Project No. 3")
      |> mes("Security Level : Grade 1-C")
      |> mes(" ")
      |> mes("Caution: Only project members")
      |> mes("of the Ymir Heart Synthesization project are authorized to view")
      |> mes("this classified document.")
      |> next()
      |> mes("Varmunt Project No. 3")
      |> mes("Security Level : Grade 1-C")
      |> mes(" ")
      |> mes("All others found reading")
      |> mes("this document are subject")
      |> mes("to punishment or dismissal.")
      |> next()
      |> mes("^3355FFYou perceive the sound of")
      |> mes("footsteps and quickly try to")
      |> mes("return the document to its")
      |> mes("original place. However,")
      |> mes("the person that has come")
      |> mes("to the archive has already")
      |> mes("seen you holding the file.^000000")
      |> next()
      |> donpcevent("Ferlock#lab::OnEnter")
      |> mes("[Ferlock]")
      |> mes("Excuse me, but are")
      |> mes("you an employee here?")
      |> mes("I've come to pick up a")
      |> mes("new Rune Stone for the")
      |> mes("Airship. Wait, wait...")
      |> mes("You look familiar...")
      |> next()

    ctx
    |> emotion(:huk, getnpcid(ctx, "Ferlock#lab"))
    |> mes("[Ferlock]")
    |> mes("That's right, aren't you the")
    |> mes("one who brought me my")
    |> mes("brother's letter? Yeah, you")
    |> mes("were asking me about the")
    |> mes("Airship's flight mechanics.")
    |> mes("So you're not an employee...")
    |> next()
    |> mes("[Ferlock]")
    |> mes("Boy, you must be more than")
    |> mes("curious to be looking up that")
    |> mes("information in a restricted")
    |> mes("area. But don't worry, you")
    |> mes("must have your reasons,")
    |> mes("so I won't call the guards.")
    |> next()
    |> mes("[Ferlock]")
    |> mes("Still, you better get out")
    |> mes("of here. The guards patrol")
    |> mes("this place regularly, so you're")
    |> mes("almost sure to get caught. Hmm,")
    |> mes("come and see me later at the")
    |> mes("Airship, alright? Now hurry!")
    |> close()
    |> donpcevent("Ferlock#lab::OnInit")
    |> changequest(8042, 8043)
    |> set_char_var(:lhz_heart, 11)
  end

  defp incorrect_guess(ctx) do
    ctx = ctx |> mes("[Password Checker]") |> mes(" ") |> mes("^333333Total of correct numbers")

    ctx =
      mes(
        ctx,
        Rathena.concat(
          Rathena.concat("in correct sequence: ^ff0000", get_local(ctx, :strike, 0)),
          "^333333"
        )
      )

    ctx =
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat("Total of correct numbers misplaced: ^ff0000", get_local(ctx, :ball, 0)),
          "^333333."
        )
      )
      |> mes("Please use these results")
      |> mes("to make a more accurate guess.^000000")
      |> next()

    if get_local(ctx, :retry, 0) > 4 do
      reveal_password(ctx)
    else
      retry_guess(ctx)
    end
  end

  defp reveal_password(ctx) do
    ctx =
      ctx
      |> mes("[Security System]")
      |> mes("^FF0000The correct password")
      |> mes("for this session was")

    ctx
    |> mes(
      Rathena.concat(
        Rathena.concat(
          Rathena.concat(
            Rathena.concat(
              Rathena.concat(
                Rathena.concat("^000000", get_local(ctx, :yagu100, 0)),
                "^FF0000 - ^000000"
              ),
              get_local(ctx, :yagu10, 0)
            ),
            "^000000 - ^000000"
          ),
          get_local(ctx, :yagu1, 0)
        ),
        "^FF0000."
      )
    )
    |> mes("Password will now be reset.^000000")
    |> close()
  end

  defp retry_guess(ctx) do
    ctx =
      ctx |> mes("[Security System]") |> mes("Beeeeep!") |> mes("Incorrect password.") |> mes(" ")

    ctx =
      case get_local(ctx, :retry, 0) do
        1 ->
          mes(ctx, "Initialing 2nd attempt...^000000")

        2 ->
          mes(ctx, "Initialing 3rd attempt...^000000")

        3 ->
          mes(ctx, "Initialing 4th attempt...^000000")

        4 ->
          mes(ctx, "Initialing final attempt...^000000")

        _ ->
          ctx
      end

    check_guesses(ctx)
  end
end
