defmodule Aesir.ZoneServer.Mmo.JobManagement.JobMapidTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.JobManagement.JobMapid

  test "every mapped job atom is known to the canonical job catalog" do
    assert :ok = JobMapid.validate!()
  end

  test "from_job/1 accepts an atom or a numeric id" do
    assert JobMapid.from_job(:novice) == 0x0
    assert JobMapid.from_job(:swordman) == 0x1
    assert JobMapid.from_job(:knight) == 0x101
    assert JobMapid.from_job(:lord_knight) == 0x100101
    assert JobMapid.from_job(:rune_knight) == 0x1101
    assert JobMapid.from_job(:dragon_knight) == 0x11101
    assert JobMapid.from_job(4054) == 0x1101
    assert JobMapid.from_job(0) == 0x0
  end

  test "from_job/1 returns -1 for mounted *2 forms, placeholders, and unknowns" do
    assert JobMapid.from_job(:lord_knight2) == -1
    assert JobMapid.from_job(:max_basic) == -1
    assert JobMapid.from_job(:job_max) == -1
    assert JobMapid.from_job(:not_a_job) == -1
    assert JobMapid.from_job(99_999) == -1
  end

  test "to_job/2 reverses from_job/1 for single-sex jobs" do
    assert JobMapid.to_job(JobMapid.from_job(:rune_knight), 1) == 4054
    assert JobMapid.to_job(JobMapid.from_job(:novice), 1) == 0
    assert JobMapid.to_job(JobMapid.from_job(:super_novice), 0) == 23
    assert JobMapid.to_job(JobMapid.from_job(:gangsi), 1) == 4050
  end

  test "to_job/2 dispatches sex-paired mapids by sex" do
    bard_mapid = JobMapid.from_job(:bard)
    assert JobMapid.from_job(:dancer) == bard_mapid
    assert JobMapid.to_job(bard_mapid, 1) == 19
    assert JobMapid.to_job(bard_mapid, 0) == 20
  end

  test "to_job/2 returns -1 for an unknown mapid" do
    assert JobMapid.to_job(0x999_999, 1) == -1
  end

  describe "EAJ_*/EAJL_* constants" do
    test "resolve flags and masks" do
      assert JobMapid.constant("EAJL_2") == {:ok, 0x300}
      assert JobMapid.constant("EAJL_2_1") == {:ok, 0x100}
      assert JobMapid.constant("EAJL_THIRD") == {:ok, 0x1000}
      assert JobMapid.constant("EAJL_UPPER") == {:ok, 0x100000}
      assert JobMapid.constant("EAJL_BABY") == {:ok, 0x200000}
      assert JobMapid.constant("EAJ_BASEMASK") == {:ok, 0xFF}
      assert JobMapid.constant("EAJ_THIRDMASK") == {:ok, 0xFFFF}
    end

    test "resolve job mapids, shared-pair names, and aliases" do
      assert JobMapid.constant("EAJ_RUNE_KNIGHT") == {:ok, 0x1101}
      assert JobMapid.constant("EAJ_KAGEROUOBORO") == {:ok, 0x109}
      assert JobMapid.constant("EAJ_SUPERNOVICE") == {:ok, 0x100}
      assert JobMapid.constant("EAJ_DEATH_KNIGHT") == {:ok, 0x10B}
      assert JobMapid.constant("EAJ_DARKCOLLECTOR") == {:ok, 0x20B}
    end

    test "returns :error for unknown names" do
      assert JobMapid.constant("EAJ_NOPE") == :error
      assert JobMapid.constant("nope") == :error
    end
  end
end
