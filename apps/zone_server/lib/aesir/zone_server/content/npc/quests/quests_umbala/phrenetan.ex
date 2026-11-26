defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsUmbala.Phrenetan do
  @moduledoc """
  Phrenetan describes her frustration with her husband.

  ## Behavior

  - She starts the domestic dispute quest for eligible characters and reacts to its completion.

  ## Credits

  - Original from rAthena, authors and Contributors
    - sabernet09
    - rAthena Team
    - x[tsk]
    - Lupus
    - PoW
    - Evera
    - SinSloth
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "um_in", x: 139, y: 48, dir: 5, sprite: 783, name: "Phrenetan", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :event_umbala, 0) >= 3 ->
        ctx
        |> mes("[Phrenetan]")
        |> mes("I am so sick and tired of")
        |> mes("my husband!! It's like he")
        |> mes("flirts with every girl")
        |> mes("in the village!")
        |> next()
        |> mes("[Phrenetan]")
        |> mes("If I see him flirting with")
        |> mes("women again...I swear...")
        |> mes("I will show him hell!!")
        |> close()

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:novice) and upper(ctx) != 2 ->
        ctx
        |> mes("[Phrenetan]")
        |> mes("Umba~ umbaumbah!")
        |> mes("Umbah woomumum!")
        |> mes("Umbah woomum umbabah!")
        |> close()

      get_char_var(ctx, :um_wind, 0) <= 3 and
          :erlang.band(get_char_var(ctx, :MISC_QUEST, 0), 32768) == 0 ->
        ctx =
          if get_char_var(ctx, :um_wind, 0) == 0, do: set_char_var(ctx, :um_wind, 1), else: ctx

        ctx
        |> emotion(:fret)
        |> mes("[Phrenetan]")
        |> mes("Umbaumbah wooga wooga")
        |> mes("Umbaumbabah babababah!")
        |> mes("Umbaum!")
        |> next()
        |> emotion(:o)
        |> mes("[Phrenetan]")
        |> mes("Umbah umbaumba umbah")
        |> mes("Umbabababah wooga woo!")
        |> mes("Wooga wooga umbabah umbaum!")
        |> next()
        |> emotion(:go)
        |> close()

      get_char_var(ctx, :um_wind, 0) == 6 or
          Rathena.truthy?(:erlang.band(get_char_var(ctx, :MISC_QUEST, 0), 32768)) ->
        ctx
        |> emotion(:fret)
        |> mes("[Phrenetan]")
        |> mes("Umbabah! Umbaumbah.....")
        |> mes("Umbaum Umbaum Wooga wooga!")
        |> mes("Wooga umumum woombababap!!!!!")
        |> next()
        |> emotion(:sweat)
        |> close()

      true ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
