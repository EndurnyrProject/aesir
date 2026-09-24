defmodule Aesir.ZoneServer.Content.Npc.Jobs.Valkyrie.MetheusSylphe do
  @moduledoc """
  The Juno library keeper who grants rebirth candidates access to the Book of Ymir for a
  donation.

  ## Behavior

  - Asks second-class characters of base level 99 and job level 50 or higher for a
    1,285,000 zeny donation that unlocks the Book of Ymir.
  - Thanks candidates who already donated and welcomes everyone else to the library.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Nana
    - Poki
    - Lupus
    - L0ne_W0lf
    - Mass Zero
    - Silentdragon
    - Vicious
    - Silent

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_in02",
        x: 88,
        y: 164,
        dir: 5,
        sprite: 742,
        name: "Metheus Sylphe",
        scope: :shared,
        unique_name: "Metheus Sylphe#Library"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @donation 1_285_000

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      not rebirth_candidate?(ctx) ->
        ctx
        |> mes("[Metheus Sylphe]")
        |> mes("Welcome to the Library of the Schweicherbil Magic Academy.")
        |> mes(
          "Here, we have a countless number of books. Please take your time and look around."
        )
        |> close()

      get_char_var(ctx, :valkyrie_Q, 0) == 0 ->
        ask_for_donation(ctx)

      true ->
        ctx
        |> mes("[Metheus Sylphe]")
        |> mes(
          "Once again, thank you for your generous donation. Feel free to read a carbon copy of the 'Book of Ymir' at your leisure."
        )
        |> close()
    end
  end

  defp rebirth_candidate?(ctx) do
    base_level(ctx) > 98 and job_level(ctx) > 49 and
      Rathena.job_id(class(ctx)) >= Rathena.job_id(:knight) and
      Rathena.job_id(class(ctx)) <= Rathena.job_id(:crusader2)
  end

  defp ask_for_donation(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Metheus Sylphe]")
      |> mes("Welcome to the Library of the Schweicherbil Magic Academy.")
      |> mes("I assume you have come here")
      |> mes("to read the 'Book of Ymir.'")
      |> next()
      |> mes("[Metheus Sylphe]")
      |> mes(
        "Unfortunately, the original copy of the book has been damaged over time. We currently only allow the public to view a copy of the book."
      )
      |> next()
      |> mes("[Metheus Sylphe]")
      |> mes(
        "Also, in order to preserve the original 'Book of Ymir,' we have decided to accept donations from people who wish to read the copy we have provided."
      )
      |> next()
      |> mes("[Metheus Sylphe]")
      |> mes("The suggested")
      |> mes("donation amount is")
      |> mes("1,285,000 zeny.")
      |> next()
      |> select(["Donate.", "Cancel."])

    cond do
      choice != 1 ->
        ctx
        |> mes("[Metheus Sylphe]")
        |> mes("Take your time, and")
        |> mes("enjoy your travels.")
        |> close()

      zeny(ctx) >= @donation ->
        ctx
        |> pay_zeny(@donation)
        |> set_char_var(:valkyrie_Q, 1)
        |> mes("[Metheus Sylphe]")
        |> mes("Thank you, your donation will be used for a good cause. You may")
        |> mes("now go in and read the book.")
        |> close()

      true ->
        ctx
        |> mes("[Metheus Sylphe]")
        |> mes(
          "Unfortunately, you don't seem to possess enough zeny at the moment. Please check your funds and come back again."
        )
        |> close()
    end
  end
end
