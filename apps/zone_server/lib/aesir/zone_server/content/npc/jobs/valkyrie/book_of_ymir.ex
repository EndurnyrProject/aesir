defmodule Aesir.ZoneServer.Content.Npc.Jobs.Valkyrie.BookOfYmir do
  @moduledoc """
  The Book of Ymir, whose legend of Valkyrie starts the rebirth quest.

  ## Behavior

  - Shows reborn and transcendent characters the forgotten path to Valhalla and can warp
    them there.
  - Lets rebirth candidates who donated to the library read the legend, which records
    the rebirth quest.
  - Shows only an ellipsis to everyone else.

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
        x: 93,
        y: 207,
        dir: 1,
        sprite: 111,
        name: "Book of Ymir",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :ADVJOB, 0) != 0 or upper(ctx) == 1 ->
        read_forgotten_path(ctx)

      rebirth_candidate?(ctx) and get_char_var(ctx, :valkyrie_Q, 0) != 0 ->
        read_valkyrie_legend(ctx)

      true ->
        ctx
        |> mes("[The Book of Ymir]")
        |> mes("...")
        |> close()
    end
  end

  defp rebirth_candidate?(ctx) do
    base_level(ctx) > 98 and job_level(ctx) > 49 and
      Rathena.job_id(class(ctx)) >= Rathena.job_id(:knight) and
      Rathena.job_id(class(ctx)) <= Rathena.job_id(:crusader2)
  end

  defp read_forgotten_path(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[The Book of Ymir]")
      |> mes(
        "...The entrance to the Hall of Honor is open to anyone who has moved forward into their next life. It is there to help heroes decide what they want to do, and can lead them to anywhere in this world."
      )
      |> next()
      |> mes("[The Book of Ymir]")
      |> mes(
        "In the Hall of Honor, everything is prepared for heroes. It is rumored that any wish that cannot be fulfilled in our reality can be realized in the Hall of Honor."
      )
      |> next()
      |> select(["Stop reading.", "Continue reading."])

    if choice == 1 do
      ctx
      |> mes("[The Book of Ymir]")
      |> mes(".....")
      |> close()
    else
      ctx
      |> mes("[The Book of Ymir]")
      |> mes(
        "There is a forgotten path which leads to the Hall of Honor, the closest place to the heavens. The ordinary will never discover this place..."
      )
      |> close()
      |> warp("valkyrie", 48, 8)
    end
  end

  defp read_valkyrie_legend(ctx) do
    ctx
    |> mes("[The Book of Ymir]")
    |> mes("...Therefore, ancient heroes were")
    |> mes("always in anguish, knowing that")
    |> mes("eventually, they were mortal and")
    |> mes("would pass from this realm...")
    |> next()
    |> mes("[The Book of Ymir]")
    |> mes("There were no documents,")
    |> mes(
      "songs, or remaining folklore that had any information on life after death. However, I recently uncovered an old scroll"
    )
    |> mes("about Valkyrie...")
    |> next()
    |> mes("[The Book of Ymir]")
    |> mes("Valkyrie...")
    |> mes("The legendary")
    |> mes("guardian angel.")
    |> mes("Angel of Ragnarok.")
    |> next()
    |> mes("[The Book of Ymir]")
    |> mes("Adventurers of great strength")
    |> mes("and bravery will be lead by")
    |> mes("Valkyrie to Valhalla, the Hall")
    |> mes("of Honor. There, they will be")
    |> mes("given a new life.")
    |> next()
    |> mes("[The Book of Ymir]")
    |> mes("Reborn, they will live again as")
    |> mes("even greater heroes that will")
    |> mes("brighten the world. Bodies that")
    |> mes("were exhausted will be filled")
    |> mes("with energy...")
    |> next()
    |> mes("[The Book of Ymir]")
    |> mes(
      "And their souls will be given abilities with the heart of Ymir. However, the heart of Ymir was totally destroyed and scattered all over the world after the battle for Rune-Midgarts."
    )
    |> next()
    |> mes("[The Book of Ymir]")
    |> mes("I have found a small amount of")
    |> mes("Ymir heart pieces over a long")
    |> mes("long period of time. But I can't")
    |> mes("confirm if the story of Valkyrie")
    |> mes("and Valhalla is true just")
    |> mes("through scientific tests.")
    |> next()
    |> mes("[The Book of Ymir]")
    |> mes("So, I am leaving this record in hope that someone in the future")
    |> mes("can confirm that Valkyrie and Valhalla actually exist...")
    |> next()
    |> set_char_var(:valkyrie_Q, 2)
    |> start_rebirth_quest()
    |> mes("[The Book of Ymir]")
    |> mes("Let the heroes live new lives")
    |> mes("so they can protect the world")
    |> mes("from danger. And then...")
    |> close()
  end

  defp start_rebirth_quest(ctx) do
    if checkquest(ctx, 1000) == -1 do
      setquest(ctx, 1000)
    else
      ctx
    end
  end
end
